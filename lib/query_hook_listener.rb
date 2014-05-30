class QueryHookListener < Redmine::Hook::ViewListener
  def view_issues_sidebar_issues_bottom(context={} )
  	if context && context[:project]
    	return link_to l(:custom_report), { :controller => 'customized_reports', :action => 'index',:id => context[:project] ,:set_filter => 1}
    end
  end

end