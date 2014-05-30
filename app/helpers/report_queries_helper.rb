module ReportQueriesHelper
	  # Retrieve query from session or build a new query

    def report_column_options_for_select(query,option_name)
      options_for_select(report_column_options(query),query.send(option_name))
    end

    def report_column_options(query)
      options = [[]]
      options += query.available_report_column.map do |field_name, field|
        [field_name, field]
      end
    end

  def retrieve_report_query
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = ReportQuery.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = ReportQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :horizontal_field => @query.horizontal_field, :vertical_field => @query.vertical_field}
    else
      # retrieve from session
      @query = nil
      @query = ReportQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= ReportQuery.new(:name => "_", :filters => session[:query][:filters], :horizontal_field => session[:query][:horizontal_field], :vertical_field => session[:query][:vertical_field])
      @query.project = @project
    end
  end

  def retrieve_report_query_from_session
    if session[:query]
      if session[:query][:id]
        @query = ReportQuery.find_by_id(session[:query][:id])
        return unless @query
      else
        @query = ReportQuery.new(:name => "_", :filters => session[:query][:filters], :horizontal_field => session[:query][:horizontal_field], :vertical_field => session[:query][:vertical_field])
      end
      if session[:query].has_key?(:project_id)
        @query.project_id = session[:query][:project_id]
      else
        @query.project = @project
      end
      @query
    end
  end



end