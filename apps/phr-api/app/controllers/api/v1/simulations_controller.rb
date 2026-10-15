module Api
  module V1
    # Endpoints that misbehave on purpose. Nothing here is part of the
    # "business" app -- they exist so there is a repeatable way to produce a
    # slow query, a chatty query pattern, a full table scan, a 500, or CPU
    # burn while validating what the platform reports.
    class SimulationsController < ApplicationController
      class SimulatedFailure < StandardError; end

      # GET /api/v1/simulate/slow_query?seconds=2
      def slow_query
        seconds = params.fetch(:seconds, 2).to_f.clamp(0.1, 10.0)

        result = ActiveRecord::Base.connection.select_value(
          ActiveRecord::Base.sanitize_sql_array(["SELECT SLEEP(?)", seconds])
        )

        render json: { simulated: "slow_query", seconds: seconds, sleep_result: result }
      end

      # GET /api/v1/simulate/n_plus_one?limit=50
      # One query for the leads, then one more per lead for its appointments.
      def n_plus_one
        limit = params.fetch(:limit, 50).to_i.clamp(1, 500)
        queries = 0

        payload = Lead.recent.limit(limit).map do |lead|
          queries += 1
          { lead_id: lead.id, appointment_count: lead.appointments.count }
        end

        render json: {
          simulated: "n_plus_one",
          leads: payload.size,
          extra_queries: queries,
          data: payload
        }
      end

      # GET /api/v1/simulate/table_scan
      # notes is an unindexed TEXT column, so the leading-wildcard LIKE has to
      # read every row.
      def table_scan
        term = params.fetch(:term, "roof").to_s.first(32)

        matches = Lead.where("notes LIKE ?", "%#{term}%").count
        plan = ActiveRecord::Base.connection.select_all(
          ActiveRecord::Base.sanitize_sql_array(
            ["EXPLAIN SELECT COUNT(*) FROM leads WHERE notes LIKE ?", "%#{term}%"]
          )
        ).to_a

        render json: { simulated: "table_scan", term: term, matches: matches, explain: plan }
      end

      # GET /api/v1/simulate/error
      def error
        raise SimulatedFailure, "simulated downstream failure in phr-api (request_id=#{request.request_id})"
      end

      # GET /api/v1/simulate/cpu?ms=500
      def cpu
        ms = params.fetch(:ms, 500).to_i.clamp(10, 5_000)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)

        iterations = 0
        iterations += 1 while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline

        render json: { simulated: "cpu", ms: ms, iterations: iterations }
      end
    end
  end
end
