require 'cgi'
require 'offin/db'
require 'offin/sql-assembler'
require 'offin/utils'


# Paginator is a class to help simplify the page-by-page displays of a
# list of packages, where that list may be growing faster than the
# person can page through it.  It provides a list of
# datamapper::package records based on filtering and pagination data
# provided by query parameters.
#
# It is used in our sinatra data analysis app within view templates.

class PackageListPaginator

  PACKAGES_PER_PAGE = 20

  # Think of a page as descending list of numeric IDs (those IDs are
  # in fact the surrogate auto-incremented keys produced for a package
  # table, created when a package starts to get ingested, so this
  # list gives us a reverse chronological browsable list).

  # There are main three ways to initialize an object in the paginator class depending on the params hash (from sinatra)
  #
  # * Provide neither BEFORE_ID nor AFTER_ID.
  #     provide a list of PAGE_SIZE packages from most recent
  #     (highest ID) to lowest.
  #
  # * Provide BEFORE_ID
  #     generate a PAGE_SIZE list of packages that should be displayed
  #     just prior to the ID with value BEFORE_ID
  #
  # * Provide AFTER_ID
  #     generate a PAGE_SIZE list of packages that should be displayed
  #     just after the ID with value AFTER_ID
  #
  # If both BEFORE_ID and AFTER_ID are used, we'll not pay any
  # attention to either of them.
  #
  # There are additional filtering parameters that are applied to the
  # entire packages list before the above logic comes into play.
  #
  # SITE is required and is the value returned from DataBase::IslandoraSite.first(:hostname => '...')

  attr_reader :packages, :count, :comment, :params, :total

  def initialize site, params = {}
    @params   = params
    @site     = site
    @packages = DataBase::IslandoraPackage.all(:order => [ :id.desc ], :id => process_params())   # process_params sets up @count, @total, @min, @max & modifies @params as side effect
    @comment  = nil
  end

  # methods to use in views to set links, e.g "<< first < previous | next > last >>" where links which may be inactive, depending.

  def has_next_page_list?
    return false if @packages.empty? or @min.nil?
    return @packages.last[:id] > @min
  end

  def has_previous_page_list?
    return false if @packages.empty? or @max.nil?
    return @packages.first[:id] < @max
  end

  def no_pages?
    @packages.empty?
  end

  def any_pages?
    not @packages.empty?
  end

  def is_first_page_list?
    return true if no_pages?  # vacuously true
    return @packages.map { |p| p[:id] }.include? @max
  end

  def is_last_page_list?
    return true if no_pages?  # vacuously true
    return @packages.map { |p| p[:id] }.include? @min
  end

  # build a query string for a link.

  def query_string additional_params = {}
    temper_params(additional_params)
    pairs = []
    @params.each { |k,v| pairs.push "#{CGI::escape(k)}=#{CGI::escape(v)}" } # ecaping the key is purely defensive.
    return '' if pairs.empty?
    return '?' + pairs.join('&')
  end

  def previous_page_list
    return "/packages" + query_string('after' => nil, 'before' => nil) if @packages.empty?
    return "/packages" + query_string('after' => nil, 'before' => @packages.first[:id])
  end

  def next_page_list
    return "/packages" + query_string('before' => nil, 'after' => nil) if @packages.empty?
    return "/packages" + query_string('before' => nil, 'after' => @packages.last[:id])
  end

  def first_page_list
    return "/packages" + query_string('after' => nil, 'before' => nil)
  end

  def csv_link
    "/csv" + query_string('after' => nil, 'before' => nil)
  end


  def offset_to_last_page
    skip  = (@count / PACKAGES_PER_PAGE) * PACKAGES_PER_PAGE
    skip -= PACKAGES_PER_PAGE if skip == @count
    return skip
  end

  # last_page_list => URL that will take us to the last page of our
  # list of packages (subject to our filters)

  def last_page_list

    sql = Utils.setup_basic_filters(SqlAssembler.new, @params.merge('site_id' => @site[:id]))

    sql.set_select 'SELECT id FROM islandora_packages'
    sql.set_order  'ORDER BY id DESC'
    sql.set_limit  'OFFSET ? LIMIT 1', offset_to_last_page

    ids = sql.execute

    return "/packages" + query_string('before' => nil, 'after' => nil) if ids.empty?
    return "/packages" + query_string('before' => nil, 'after' => ids[0] + 1)
  end

  # parameter checking convience funtions for view, e.g.  :select => paginator.is_content_type?('islandora:sp_pdf')

  def is_content_type? str
    @params['content-type'] == str
  end

  def is_status? str
    @params['status'] == str
  end

  def is_collection? str
    @params['collection'] == str
  end

  # add a comment to place on a page - useful for debugging

  def add_comment str
    @comment = '' unless @comment
    @comment += str + '<br>'
  end

  def comment?
    @comment
  end


  private

  # We do database queries in two steps.  First, subject to page
  # positions (query parameters :before, :after) and search parameters
  # (everything else), we create an SQL statement that selects a
  # page's worth of the DB's islandora_packages.id's, a sequence of
  # integers.  Once that's done, we'll use the id's to instantiate the
  # datamapper objects that will be passed to our view templates.
  #
  # process_params() supplies the logic for this first part. Note that
  # @params is user-supplied input and untrustworthy - thus we use
  # placeholders - the SQLAssembler object helps keep track of all of
  # those.
  #
  # N.B.: some of this results in very PostgreSQL-specific SQL.

  def process_params
    temper_params()

    # First, let's find out the total size of the db:

    sql = SqlAssembler.new
    sql.set_select 'SELECT count(*) FROM islandora_packages'
    sql.add_condition 'islandora_site_id = ?', @site[:id]    # note: this hangs around for all three invocations of sql.execute

    @total = sql.execute()[0]

    # Second: find the limits of our filtered package set (conditions
    # are added by setup_basic_filters)

    sql.set_select 'SELECT min(id), max(id), count(*) FROM islandora_packages'
    Utils.setup_basic_filters(sql, @params)

    rec = sql.execute()[0]

    @min, @max, @count = rec.min, rec.max, rec.count

    # Now we can figure out where the page of interest starts (using
    # one of the params 'before', 'after') and get the page-sized list
    # we want; if there are no 'before' or 'after' parameters we'll
    # generate a page list starting from the most recent package
    # (i.e. the first page)

    sql.set_select 'SELECT DISTINCT id FROM islandora_packages'
    sql.set_limit  'LIMIT ?', PACKAGES_PER_PAGE
    sql.set_order  'ORDER BY id DESC'

    if val = @params['before']
      sql.add_condition('id > ?', val)
      sql.set_order('ORDER BY id ASC')
    end

    if val = @params['after']
      sql.add_condition('id < ?', val)
    end

    return sql.execute
  end

  # temper_params() removes empty query parameters from @params (e.g. if
  # a query string was "?foo=this&bar=&quux=that", @params is
  # initially { 'foo' => 'this, 'bar' => nil, 'quux' => 'that' }, so
  # temper_params() removes 'bar' entirely). Make sure values are
  # strings, etc, maybe do some modifications using additional_params
  # hash.

  def temper_params additional_params = {}
    @params.merge! additional_params
    @params.each { |k,v| @params[k] = v.to_s;  @params.delete(k) if @params[k].empty? }

    # clear invalid dates

    from, to = Utils.parse_dates(@params['from'], @params['to'])
    @params.delete('from') unless from
    @params.delete('to') unless to

    if @params['before'] and @params['after']  # special case - there should be at most one of these, if not, remove both (do we really have to do this? it's mostly defensive programming...)
       @params.delete('before')
       @params.delete('after')
    end

    @params.each { |k,v| @params[k] = v.strip }  # remove extra spaces
  end

end # of class PackageListPaginator


# PackagePaginator is class to help us build views, for linking to next/previous packages that meet a list of search criteria.

class PackagePaginator

  attr_reader :package, :params, :id

  # As in PackageListPaginator, SITE is the value returned from
  # DataBase::IslandoraSite.first(:hostname => '...islandora site...')
  # ID is the integer identifier (auto incremented) surrogate key for
  # the package table, extracted from the URL, and PARAMS is from the
  # query paramters. So both the latter are user-supplied.

  def initialize site, params = {}

    @id           = params['id'].to_i
    @params       = temper_params(params, 'after' => nil, 'before' => nil, 'id' => nil, 'captures' => nil)   # 'captures' introduced by sinatra
    @site         = site
    @package      = DataBase::IslandoraPackage.all(:id => @id)
    @comment      = nil
    @previous_id  = get_previous_id @id, @params
    @next_id      = get_next_id @id, @params

  end

  def temper_params params, additional_params = {}
    result = params.merge additional_params
    result.each { |k,v| result[k] = v.to_s.strip;  result.delete(k) if result[k].empty? }
  end

  def get_previous_id id, params
    sql = Utils.setup_basic_filters(SqlAssembler.new, params.merge('site_id' => @site[:id], 'before' => nil, 'after' => nil))
    sql.set_select    'SELECT id from islandora_packages'
    sql.set_limit     'LIMIT 1'
    sql.set_order     'ORDER BY id ASC'
    sql.add_condition 'id > ?', id

    # sql.dump
    return sql.execute()[0]
  end

  def get_next_id id, params
    sql = Utils.setup_basic_filters(SqlAssembler.new, params.merge('site_id' => @site[:id], 'before' => nil, 'after' => nil))
    sql.set_select    'SELECT id from islandora_packages'
    sql.set_limit     'LIMIT 1'
    sql.set_order     'ORDER BY id DESC'
    sql.add_condition 'id < ?', id

    # sql.dump
    return sql.execute()[0]
  end

  def query_string
    pairs = []
    @params.each { |k,v| pairs.push "#{CGI::escape(k)}=#{CGI::escape(v)}" } # ecaping the key is purely defensive.
    return '' if pairs.empty?
    return '?' + pairs.join('&')
  end

  def has_next_page?
    not @next_id.nil?
  end

  def has_previous_page?
    not @previous_id.nil?
  end

  def previous_page
    "/packages/#{@previous_id}" + query_string
  end

  def next_page
    "/packages/#{@next_id}" + query_string
  end


  def up_page
    "/packages" + query_string
  end


end
