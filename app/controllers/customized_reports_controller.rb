class CustomizedReportsController < ApplicationController
  unloadable
  before_filter :find_project
  helper :customized_reports
  include CustomizedReportsHelper
  helper :queries
  include QueriesHelper
  helper :report_queries
  include ReportQueriesHelper
  def index
    retrieve_report_query
    @result = @query.count_and_group_by
    @data = @result[:data]
    @rows = @result[:rows]
    @cols = @result[:cols]
    @h_field = @query.horizontal_field
    @v_field = @query.vertical_field
    @h_filter = @query.get_filter_name(@h_field)
    @v_filter = @query.get_filter_name(@v_field)
    respond_to do |format|
        format.html { render :action => "index", :layout => !request.xhr? }
    end
  end
end
