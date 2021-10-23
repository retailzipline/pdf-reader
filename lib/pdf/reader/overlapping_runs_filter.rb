# typed: strict
# coding: utf-8
# frozen_string_literal: true

class PDF::Reader
  # remove duplicates from a collection of TextRun objects. This can be helpful when a PDF
  # uses slightly offset overlapping characters to achieve a fake 'bold' effect.
  class OverlappingRunsFilter
    extend T::Sig

    # This should be between 0 and 1. If TextRun B obscures this much of TextRun A (and they
    # have identical characters) then one will be discarded
    OVERLAPPING_THRESHOLD = 0.5

    sig {params(runs: T::Array[PDF::Reader::TextRun]).returns(T::Array[PDF::Reader::TextRun])}
    def self.exclude_redundant_runs(runs)
      sweep_line_status = Array.new
      event_point_schedule = Array.new
      to_exclude = []

      runs.each do |run|
        event_point_schedule << EventPoint.new(run.x, run)
        event_point_schedule << EventPoint.new(run.endx, run)
      end

      event_point_schedule.sort! { |a,b| a.x <=> b.x }

      event_point_schedule.each do |event_point|
        run = event_point.run

        if event_point.start?
          if detect_intersection(sweep_line_status, event_point)
            to_exclude << run
          end
          sweep_line_status.push(run)
        else
          sweep_line_status.delete(run)
        end
      end
      runs - to_exclude
    end

    sig {
      params(
        sweep_line_status: T::Array[PDF::Reader::TextRun],
        event_point: EventPoint
      ).returns(T::Boolean)
    }
    def self.detect_intersection(sweep_line_status, event_point)
      sweep_line_status.each do |open_text_run|
        if event_point.x >= open_text_run.x &&
            event_point.x <= open_text_run.endx &&
            open_text_run.intersection_area_percent(event_point.run) >= OVERLAPPING_THRESHOLD
          return true
        end
      end
      return false
    end
  end

  # Utility class used to avoid modifying the underlying TextRun objects while we're
  # looking for duplicates
  class EventPoint
    extend T::Sig

    sig { returns(Numeric) }
    attr_reader :x

    sig { returns(PDF::Reader::TextRun) }
    attr_reader :run

    sig {params(x: Numeric, run: PDF::Reader::TextRun).void }
    def initialize(x, run)
      @x = x
      @run = run
    end

    sig { returns(T::Boolean) }
    def start?
      @x == @run.x
    end
  end

end
