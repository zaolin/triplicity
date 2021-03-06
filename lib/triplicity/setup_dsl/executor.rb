#
# executor.rb - perform configuration captured by DSL
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/primary'
require 'triplicity/duplication_plan'
require 'triplicity/backup_job'

module Triplicity
  module SetupDsl
    class Executor
      def initialize(application)
        @application = application

        @dsl_primaries = {}
        @primaries = Hash.new do |hash, key|
          dsl_primary = @dsl_primaries[key]
          hash[key] = Triplicity::Primary.new(dsl_primary.path, 'currently unused')
        end
        @duplications = Hash.new { |hash, key| hash[key] = [] }
        @schedules = []
      end

      def register_primary(dsl_primary)
        @dsl_primaries[dsl_primary.object_id] = dsl_primary
      end

      def register_duplication_for(dsl_primary, kind, options)
        @duplications[dsl_primary.object_id] << [kind, options]
      end

      def register_backup_schedule(primary, seconds, executions)
        @schedules << [primary, seconds, executions]
      end

      def perform
        @schedules.each do |primary, seconds, executions|
          backup_config = {
            'executions' => executions,
            'seconds' => seconds
          }

          primary = primary(primary)
          BackupJob.new(@application, primary, backup_config)
        end

        @duplications.each_pair do |primary_id, data|
          primary = primary(primary_id)

          raise "something went wrong" unless
            data.all? { |item| item.first == 'fs_path_on_device' }

          options_array = data.map(&:last)

          options = {
            destinations: options_array
          }
          DuplicationPlan.new(options, primary, @application)
        end
      end

      private

      def dsl_primaries
        @dsl_primaries ||= {}
      end

      def primary(dsl_primary)
        dsl_primary = dsl_primary.object_id unless dsl_primary.is_a?(Fixnum)
        @primaries[dsl_primary]
      end
    end
  end
end
