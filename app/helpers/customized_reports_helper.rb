module CustomizedReportsHelper



  def sidebar_queries
    unless @sidebar_queries
      @sidebar_queries = ReportQuery.visible.
        order("#{Query.table_name}.name ASC").
        # Project specific queries and global queries
        where(@project.nil? ? ["project_id IS NULL"] : ["project_id IS NULL OR project_id = ?", @project.id]).
        all
    end
    @sidebar_queries
  end

  def query_links(title, queries)
    return '' if queries.empty?
    # links to #index on issues/show
    url_params = controller_name == 'issues' ? {:controller => 'issues', :action => 'index', :project_id => @project} : params

    content_tag('h3', title) + "\n" +
      content_tag('ul',
        queries.collect {|query|
            css = 'query'
            css << ' selected' if query == @query
            content_tag('li', link_to(query.name, url_params.merge(:query_id => query), :class => css))
          }.join("\n").html_safe,
        :class => 'queries'
      ) + "\n"
  end

  def render_sidebar_queries
    out = ''.html_safe
    out << query_links(l(:label_my_report_queries), sidebar_queries.select(&:is_private?))
    out << query_links(l(:label_report_query_plural), sidebar_queries.reject(&:is_private?))
    out
  end

  def sum_of_data(data,field,field_value)
    if field == 'row'
      index = 0
    elsif field == 'col'
      index = 1
    end
    total = 0
    data.map do |key,value|
      if key[index] == field_value
        total = total + value
      end
    end
    total
  end

  def aggregate_of_status(data,field,field_value,option={})
    if field == 'row'
      index = 0
    elsif field == 'col'
      index = 1
    end
    open_total = 0
    close_total = 0
    data.map do |key,value|
      if key[index] == field_value
        if IssueStatus.find(key[(1-index)]).is_closed
          close_total = close_total + value
        else
          open_total = open_total + value
        end
      end
    end
    [open_total,close_total]
  end

  def custom_report_link(name,project,options={})
    if name.present?
      link_to name,custom_report_path(project,options)
    else
      '-'
    end
  end
  def custom_report_path(project,options={})
    f =[]
    op ={}
    values ={}
    options.map do |key,value|
      if key == :h_status_filter_op
        key = 'status_id'
        f << key
        op[key] = value
      else
        f << key
        values[key] = ([]<<value)
        op[key] = '='
      end
    end
    @query.filters.map do |key,value|
      unless f.include?(key)
        f << key
        values[key] = value[:values]
        op[key] = value[:operator]
      end
    end
    parameters = {:set_filter => 1}.merge({:f=>f,:op=>op,:values=>values})
    project_issues_path(project, parameters)
  end
end

