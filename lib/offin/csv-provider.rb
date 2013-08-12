require 'datamapper'
require 'offin/sql-assembler'
require 'offin/utils'
require 'csv'


class CsvProvider

  def initialize site, params = {}
    params.each { |k,v| params[k] = v.to_s;  params.delete(k) if params[k].empty? }
    @params = params
    @site   = site
  end

  def each
    yield csv_title
    csv_data.each do |rec|
      yield CSV.generate_line([ rec.package_name, rec.digitool_id, rec.islandora_pid, rec.content_model, rec.time_started.to_s, rec.time_finished.to_s, rec.bytes_ingested ])
    end
  end

  private

  # csv_data() will work for a few tens of thousands of records, but
  # we'll need to chunk out the sql for much more than that, if it
  # ever becomes necessary.

  def cvs_data
    sql = Utils.setup_basic_filters(SqlAssembler.new, @params.merge('site_id' => @site[:id]))
    sql.set_select 'SELECT package_name, digitool_id, islandora_pid, content_model, time_started, time_finished, bytes_ingested FROM islandora_packages'
    sql.set_order  'ORDER BY id DESC'
    return sql.execute
  end

  def csv_title
    return '"package name", "digitool id", "islandora pid", "content model", "time started", "time finished", "raw bytes ingested"'
  end

end
