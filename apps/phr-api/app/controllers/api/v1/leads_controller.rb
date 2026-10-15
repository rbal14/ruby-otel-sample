module Api
  module V1
    class LeadsController < ApplicationController
      def index
        page, per_page = pagination

        leads = Lead.by_status(params[:status])
                    .by_source(params[:source])
                    .recent
                    .limit(per_page)
                    .offset((page - 1) * per_page)

        render json: {
          page: page,
          per_page: per_page,
          total: Lead.by_status(params[:status]).by_source(params[:source]).count,
          leads: leads.as_json(include: { appointments: { only: %i[id scheduled_at status outcome] } })
        }
      end

      def show
        lead = Lead.find(params[:id])
        render json: lead.as_json(include: :appointments)
      end

      def create
        lead = Lead.new(lead_params)

        if lead.save
          render json: lead, status: :created
        else
          render json: { error: "validation_failed", messages: lead.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def update
        lead = Lead.find(params[:id])

        if lead.update(lead_params)
          render json: lead
        else
          render json: { error: "validation_failed", messages: lead.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # Aggregate rollup. Heavier SQL than the CRUD actions, which makes it a
      # good target when looking at query performance.
      def stats
        by_status = Lead.group(:status).count
        by_source = Lead.group(:source).count

        pipeline = Lead.where(status: %w[qualified appointment_set])
                       .select("product_interest, COUNT(*) AS lead_count, AVG(score) AS avg_score, SUM(estimated_value) AS pipeline_value")
                       .group(:product_interest)
                       .order("pipeline_value DESC")

        render json: {
          total_leads: Lead.count,
          total_appointments: Appointment.count,
          by_status: by_status,
          by_source: by_source,
          pipeline_by_product: pipeline.map { |row|
            {
              product_interest: row.product_interest,
              lead_count: row.lead_count,
              avg_score: row.avg_score.to_f.round(1),
              pipeline_value: row.pipeline_value.to_f.round(2)
            }
          }
        }
      end

      private

      def lead_params
        params.require(:lead).permit(
          :first_name, :last_name, :email, :phone, :zip_code,
          :source, :product_interest, :status, :score, :estimated_value, :notes
        )
      end
    end
  end
end
