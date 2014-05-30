# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw do
match 'projects/:id/issues/customized_reports',:to => 'customized_reports#index', :as => 'customized_reports'
resources :projects do
resources :report_queries
end
resources :report_queries
end