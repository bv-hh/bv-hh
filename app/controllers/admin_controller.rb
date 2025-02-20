class AdminController < ApplicationController
  auth = Rails.application.credentials.dig(Rails.env.to_sym, :admin_auth)
  if auth.present?
    http_basic_authenticate_with name: auth[:username], password: auth[:password], except: :index
  end

  def show
    @db_cache_stats = ActiveRecord::Base.connection.execute(cache_sql).first
    @index_cache_stats = ActiveRecord::Base.connection.execute(index_cache_sql).first
    @index_stats = ActiveRecord::Base.connection.execute(indexes_sql)
    @table_size = ActiveRecord::Base.connection.execute(table_size_sql)
  end

  protected

  def cache_sql
    <<-SQL.squish
      SELECT
        sum(heap_blks_read) as heap_read,
        sum(heap_blks_hit)  as heap_hit,
        (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) as ratio
      FROM
        pg_statio_user_tables
    SQL
  end

  def index_cache_sql
    <<-SQL.squish
      SELECT
        sum(idx_blks_read) as idx_read,
        sum(idx_blks_hit)  as idx_hit,
        (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio
      FROM
        pg_statio_user_indexes
    SQL
  end

  def indexes_sql
    <<-SQL.squish
      SELECT
        relname,
        CASE WHEN (seq_scan + idx_scan) > 0  THEN 100 * idx_scan / (seq_scan + idx_scan) ELSE 0 END percent_of_times_index_used,
        n_live_tup rows_in_table
      FROM
        pg_stat_user_tables
      ORDER BY
        n_live_tup DESC
    SQL
  end

  def table_size_sql
    <<-SQL.squish
      SELECT
        table_name,
        pg_table_size(table_name::text) AS table_size,
        pg_indexes_size(table_name::text) AS indexes_size,
        pg_total_relation_size(table_name::text) AS total_size
      FROM information_schema.tables
      WHERE table_schema = 'public'
      ORDER BY total_size DESC
    SQL
  end
end
