# frozen_string_literal: true

# Nightly: imports the Bürgerschaft's new Drucksachen and brings open Vorgänge
# up to date (ProceedingImporter). ParlDok gets one request at a time, so the
# run is bounded by WINDOW rather than by what there is to do: the first nights
# work through the backfill, later ones finish in minutes. A deploy in the
# middle loses nothing; the next run picks up where this one stopped.
class CheckForProceedingUpdatesJob < ApplicationJob
  WINDOW = 2.hours

  queue_as :documents

  def perform
    ProceedingImporter.new.import!(deadline: WINDOW.from_now)
  end
end
