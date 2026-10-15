module Api
  module V1
    class AppointmentsController < ApplicationController
      def index
        page, per_page = pagination

        appointments = Appointment.by_status(params[:status])
                                  .includes(:lead)
                                  .order(scheduled_at: :desc)
                                  .limit(per_page)
                                  .offset((page - 1) * per_page)

        render json: {
          page: page,
          per_page: per_page,
          total: Appointment.by_status(params[:status]).count,
          appointments: appointments.map { |appointment| serialize(appointment) }
        }
      end

      def show
        render json: serialize(Appointment.find(params[:id]))
      end

      def create
        appointment = Appointment.new(appointment_params)

        if appointment.save
          render json: serialize(appointment), status: :created
        else
          render json: { error: "validation_failed", messages: appointment.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      def update
        appointment = Appointment.find(params[:id])

        if appointment.update(appointment_params)
          render json: serialize(appointment)
        else
          render json: { error: "validation_failed", messages: appointment.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      private

      def serialize(appointment)
        appointment.as_json.merge(
          "lead" => appointment.lead.as_json(only: %i[id first_name last_name email zip_code product_interest])
        )
      end

      def appointment_params
        params.require(:appointment).permit(
          :lead_id, :scheduled_at, :rep_name, :branch, :status, :outcome, :quoted_amount, :notes
        )
      end
    end
  end
end
