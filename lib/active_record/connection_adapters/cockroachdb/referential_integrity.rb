# frozen_string_literal: true

# The PostgresSQL Adapter's ReferentialIntegrity module can disable and
# re-enable foreign key constraints by disabling all table triggers. Since
# triggers are not available in CockroachDB, we have to remove foreign keys and
# re-add them via the ActiveRecord API.
#
# This module is commonly used to load test fixture data without having to worry
# about the order in which that data is loaded.
module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module ReferentialIntegrity
        def disable_referential_integrity
          foreign_keys = tables.map { |table| foreign_keys(table) }.flatten

          foreign_keys.each do |foreign_key|
            remove_foreign_key(foreign_key.from_table, name: foreign_key.options[:name])
          end

          yield

          foreign_keys.each do |foreign_key|
            begin
              add_foreign_key(foreign_key.from_table, foreign_key.to_table, **foreign_key.options)
            rescue ActiveRecord::StatementInvalid => error
              if error.cause.class == PG::DuplicateObject
                # This error is safe to ignore because the yielded caller
                # already re-added the foreign key constraint.
              else
                raise error
              end
            end
          end
        end
      end
    end
  end
end
