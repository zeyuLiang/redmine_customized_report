class ReportQuery < Query

  self.queried_class = Issue
  DEFAULT_REPORT_COLUMNS = [
      [l(:field_tracker),"tracker"],
      [l(:field_status),"status"],
      [l(:field_priority),"priority"],
      [l(:field_author),"author"],
      [l(:field_assigned_to),"assigned_to"],
      [l(:field_category),"category"],
      [l(:field_fixed_version),"fixed_version"],
      [l(:field_member_of_group),"group"]
      ]
  COLUMN_TYPES = { 
    :tracker => "Tracker",
    :status => "IssueStatus",
    :priority => "IssuePriority",
    :author => "User",
    :assigned_to => "Principal",
    :category => "IssueCategory",
    :fixed_version => "Version",
    :group => "Group"
  }

  scope :visible, lambda {|*args|
    user = args.shift || User.current
    base = Project.allowed_to_condition(user, :view_issues, *args)
    scope = includes(:project).where("#{table_name}.project_id IS NULL OR (#{base})")

    if user.admin?
      scope.where("#{table_name}.visibility <> ? OR #{table_name}.user_id = ?", VISIBILITY_PRIVATE, user.id)
    elsif user.memberships.any?
      scope.where("#{table_name}.visibility = ?" +
        " OR (#{table_name}.visibility = ? AND #{table_name}.id IN (" +
          "SELECT DISTINCT q.id FROM #{table_name} q" +
          " INNER JOIN #{table_name_prefix}queries_roles#{table_name_suffix} qr on qr.query_id = q.id" +
          " INNER JOIN #{MemberRole.table_name} mr ON mr.role_id = qr.role_id" +
          " INNER JOIN #{Member.table_name} m ON m.id = mr.member_id AND m.user_id = ?" +
          " WHERE q.project_id IS NULL OR q.project_id = m.project_id))" +
        " OR #{table_name}.user_id = ?",
        VISIBILITY_PUBLIC, VISIBILITY_ROLES, user.id, user.id)
    elsif user.logged?
      scope.where("#{table_name}.visibility = ? OR #{table_name}.user_id = ?", VISIBILITY_PUBLIC, user.id)
    else
      scope.where("#{table_name}.visibility = ?", VISIBILITY_PUBLIC)
    end
  }

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= { 'status_id' => {:operator => "o", :values => [""]} }
  end

  # Returns true if the query is visible to +user+ or the current user.
  def visible?(user=User.current)
    return true if user.admin?
    return false unless project.nil? || user.allowed_to?(:view_issues, project)
    case visibility
    when VISIBILITY_PUBLIC
      true
    when VISIBILITY_ROLES
      if project
        (user.roles_for_project(project) & roles).any?
      else
        Member.where(:user_id => user.id).joins(:roles).where(:member_roles => {:role_id => roles.map(&:id)}).any?
      end
    else
      user == self.user
    end
  end

  def is_private?
    visibility == VISIBILITY_PRIVATE
  end

  def is_public?
    !is_private?
  end

  def horizontal_field
    r = options[:horizontal_field] || 'status'
    r.to_s
  end

  def horizontal_field=(arg)
    options[:horizontal_field] = arg
  end

  def vertical_field
    r = options[:vertical_field] || 'assigned_to'
    r .to_s
  end

  def vertical_field=(arg)
    options[:vertical_field] = arg
  end

  def build_from_params(params)
    super
    self.horizontal_field = params[:horizontal_field] || (params[:query] && params[:query][:horizontal_field])
    self.vertical_field = params[:vertical_field] || (params[:query] && params[:query][:vertical_field])
    self
  end

  def available_report_column
  	if project
      issue_custom_fields = project.all_issue_custom_fields
    else
      issue_custom_fields = IssueCustomField.where(:is_for_all => true)
    end
    @available_report_columns ||= DEFAULT_REPORT_COLUMNS
 	  add_custom_fields_columns_for_report(issue_custom_fields)
    @available_report_columns.uniq
  end

  def add_custom_fields_columns_for_report(fields)
  	#only list style like custom_field_values should be group
  	fields.visible.where(:is_filter => true).where("INSTR('list user version',field_format)>0").sorted.each do |field|
  	  filter_id = "cf_#{field.id}"
      filter_name = field.name
      @available_report_columns << [filter_name,filter_id]	
  	end
  end

  def initialize_available_filters
    principals = []
    subprojects = []
    versions = []
    categories = []
    issue_custom_fields = []

    if project
      principals += project.principals.sort
      unless project.leaf?
        subprojects = project.descendants.visible.all
        principals += Principal.member_of(subprojects)
      end
      versions = project.shared_versions.all
      categories = project.issue_categories.all
      issue_custom_fields = project.all_issue_custom_fields
    else
      if all_projects.any?
        principals += Principal.member_of(all_projects)
      end
      versions = Version.visible.where(:sharing => 'system').all
      issue_custom_fields = IssueCustomField.where(:is_for_all => true)
    end
    principals.uniq!
    principals.sort!
    users = principals.select {|p| p.is_a?(User)}

    add_available_filter "status_id",
      :type => :list_status, :values => IssueStatus.sorted.collect{|s| [s.name, s.id.to_s] }

    if project.nil?
      project_values = []
      if User.current.logged? && User.current.memberships.any?
        project_values << ["<< #{l(:label_my_projects).downcase} >>", "mine"]
      end
      project_values += all_projects_values
      add_available_filter("project_id",
        :type => :list, :values => project_values
      ) unless project_values.empty?
    end

    add_available_filter "tracker_id",
      :type => :list, :values => trackers.collect{|s| [s.name, s.id.to_s] }
    add_available_filter "priority_id",
      :type => :list, :values => IssuePriority.all.collect{|s| [s.name, s.id.to_s] }

    author_values = []
    author_values << ["<< #{l(:label_me)} >>", "me", 'wo'] if User.current.logged?
    author_values += users.collect{|s| [s.name, s.id.to_s] }
    add_available_filter("author_id",
      :type => :list, :values => author_values
    ) unless author_values.empty?

    assigned_to_values = []
    assigned_to_values << ["<< #{l(:label_me)} >>", "me", 'wo'] if User.current.logged?
    assigned_to_values += (Setting.issue_group_assignment? ?
                              principals : users).collect{|s| [s.name, s.id.to_s] }
    add_available_filter("assigned_to_id",
      :type => :list_optional, :values => assigned_to_values
    ) unless assigned_to_values.empty?

    group_values = Group.all.collect {|g| [g.name, g.id.to_s] }
    add_available_filter("member_of_group",
      :type => :list_optional, :values => group_values
    ) unless group_values.empty?

    role_values = Role.givable.collect {|r| [r.name, r.id.to_s] }
    add_available_filter("assigned_to_role",
      :type => :list_optional, :values => role_values
    ) unless role_values.empty?

    if versions.any?
      add_available_filter "fixed_version_id",
        :type => :list_optional,
        :values => versions.sort.collect{|s| ["#{s.project.name} - #{s.name}", s.id.to_s] }
    end

    if categories.any?
      add_available_filter "category_id",
        :type => :list_optional,
        :values => categories.collect{|s| [s.name, s.id.to_s] }
    end

    add_available_filter "subject", :type => :text
    add_available_filter "created_on", :type => :date_past
    add_available_filter "updated_on", :type => :date_past
    add_available_filter "closed_on", :type => :date_past
    add_available_filter "start_date", :type => :date
    add_available_filter "due_date", :type => :date
    add_available_filter "estimated_hours", :type => :float
    add_available_filter "done_ratio", :type => :integer

    if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
      User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
      add_available_filter "is_private",
        :type => :list,
        :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]]
    end

    if User.current.logged?
      add_available_filter "watcher_id",
        :type => :list, :values => [["<< #{l(:label_me)} >>", "me"]]
    end

    if subprojects.any?
      add_available_filter "subproject_id",
        :type => :list_subprojects,
        :values => subprojects.collect{|s| [s.name, s.id.to_s] }
    end

    add_custom_fields_filters(issue_custom_fields)

    add_associations_custom_fields_filters :project, :author, :assigned_to, :fixed_version

    IssueRelation::TYPES.each do |relation_type, options|
      add_available_filter relation_type, :type => :relation, :label => options[:name]
    end

    Tracker.disabled_core_fields(trackers).each {|field|
      delete_available_filter field
    }
  end


  # Query data generator for report table 
  # return data like {:data =>{[horizontal_field_id,vertical_field_id]=>count,..},:rows=>[[field_name,field_id],..],:cols=>[[field_name,field_id],..]}
  # for example {:data => {[1,2]=>10,[2,3]=>11,[3,4]=>15}},:rows=>[['rname1',1],['rname2',2],['rname3',3]],:cols=>[['cname2',2],['cname3',3],['cname4',4]]}
  def count_and_group_by()

    data = nil
    rows = []
    cols = []
    r = {}

    if horizontal_field =~ /cf_(\d+)$/ && vertical_field =~ /cf_(\d+)$/
      begin
        cf_h = CustomField.find(horizontal_field.sub("cf_", "").to_i)
        if cf_h.field_format == "user"
          hd_sel = "us_h.login AS cf1_value"
          hd_sql = "INNER JOIN custom_values AS cf1 ON cf1.customized_id = issues.id AND cf1.customized_type = 'Issue'
                    INNER JOIN `users` as us_h ON us_h.`id` = cf1.value"
          hd_grp = "us_h.login"
        elsif cf_h.field_format == "version"
          hd_sel = "ve_h.name AS cf1_value"
          hd_sql = "LEFT JOIN custom_values AS cf1 ON cf1.customized_id = issues.id AND cf1.customized_type = 'Issue'
                    INNER JOIN `versions` as ve_h ON ve_h.`id` = cf1.value"
          hd_grp = "cf1.value"
        else
          hd_sel = "cf1.value AS cf1_value"
          hd_sql = "INNER JOIN custom_values AS cf1 ON cf1.customized_id = issues.id AND cf1.customized_type = 'Issue'"
          hd_grp = "cf1.value"
        end

        cf_v = CustomField.find(vertical_field.sub("cf_", "").to_i)
        if cf_v.field_format == "user"
          vd_sel = "us_v.login AS cf2_value"
          vd_sql = "LEFT JOIN custom_values AS cf2 ON cf2.customized_id = cf1.customized_id
                    INNER JOIN `users` as us_v ON us_v.`id` = cf2.value"
          vd_grp = "us_v.login"
        elsif cf_v.field_format == "version"
          vd_sel = "ve_v.name AS cf2_value"
          vd_sql = "LEFT JOIN custom_values AS cf2 ON cf2.customized_id = cf1.customized_id
                    INNER JOIN `versions` as ve_v ON ve_v.`id` = cf2.value"
          vd_grp = "cf2.value"
        else
          vd_sel = "cf2.value AS cf2_value"
          vd_sql = "LEFT JOIN custom_values AS cf2 ON cf2.customized_id = cf1.customized_id"
          vd_grp = "cf2.value"
        end

        data= Issue.select(hd_sel).
                    select(vd_sel).
                    joins(hd_sql).
                    joins(vd_sql).
                    joins(:project).
                    where(statement + " AND cf1.custom_field_id = #{cf_h.id} AND cf2.custom_field_id = #{cf_v.id}").
                    group(hd_grp,vd_grp).
                    count
      rescue ActiveRecord::RecordNotFound
        data 
      rescue Exception => e
        data
      end
    else
      if horizontal_field == "group"
        hd_field_sym = "INNER JOIN (SELECT user_id,group_id FROM groups_users UNION SELECT id AS user_id, id AS group_id FROM users WHERE TYPE = 'Group') AS groups_users ON issues.assigned_to_id = groups_users.user_id "
        hd_field_id = horizontal_field + '_id'
      elsif horizontal_field =~ /cf_(\d+)$/
        hd_field_sym = "INNER JOIN custom_values ON custom_values.customized_id = issues.id AND custom_values.customized_type = 'Issue' AND custom_values.custom_field_id = #{$1}"
        hd_field_id = "custom_values.value"
      else
        hd_field_sym = horizontal_field.to_sym
        hd_field_sel = vertical_field == "group" || vertical_field =~ /cf_(\d+)$/ ? "#{horizontal_field}_id" :  "issues.#{horizontal_field}_id AS #{horizontal_field}_id"
        hd_field_id = 'issues.' + horizontal_field + '_id'
      end
        
      if vertical_field == "group"
        vd_field_sym = "INNER JOIN (SELECT user_id,group_id FROM groups_users UNION SELECT id AS user_id, id AS group_id FROM users WHERE TYPE = 'Group') AS groups_users ON issues.assigned_to_id = groups_users.user_id "
        vd_field_id = vertical_field + '_id'
      elsif vertical_field =~ /cf_(\d+)$/
        vd_field_sym = "INNER JOIN custom_values ON custom_values.customized_id = issues.id AND custom_values.customized_type = 'Issue' AND custom_values.custom_field_id = #{$1}"
        vd_field_id = "custom_values.value"
      else
        vd_field_sym = vertical_field.to_sym
        vd_field_sel = horizontal_field == "group" || horizontal_field =~ /cf_(\d+)$/ ? "#{vertical_field}_id" : "issues.#{vertical_field}_id AS #{vertical_field}_id"
        vd_field_id = 'issues.' + vertical_field + '_id'
      end 

      begin
        data = Issue.select(hd_field_sel).
        select(vd_field_sel).
        joins(hd_field_sym).
        joins(vd_field_sym).
        joins(:project).
        where(statement).
        group(hd_field_id,vd_field_id).
        count
      rescue ActiveRecord::RecordNotFound
        data 
      end
    end

    r[:data] = data
    data.each do |k,v|
      rows << k[0]
      cols << k[1]
    end
    rows = rows.uniq
    cols = cols.uniq

    rows = find_name(rows,horizontal_field)
    cols = find_name(cols,vertical_field)

    r[:rows] = rows
    r[:cols] = cols
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
  
  def find_name(rows,field)
    rows_detail=[]
    rows.map do |row|
      if field =~ /cf_(\d+)$/
        cv = CustomField.find($1)
        if cv.field_format == "user"
          field_type = "Principal"
        end
      else
        field_type = COLUMN_TYPES[field.to_sym]
      end
      field_value = row
      if field_type.present? && field_value.is_a?(Integer)
        field_value_name = field_type.constantize().find(field_value).name
      else
        field_value_name = field_value
      end
      rows_detail << [field_value_name,field_value]
    end
    rows_detail
  end

  def get_filter_name(field)
    if field =~ /cf_(\d+)$/
      field_name = field
    elsif field == "group"
      field_name = "member_of_group"
    else
      field_name = field + '_id'
    end
    field_name
  end
  
  # Returns the issue count by group or nil if query is not grouped
  def issue_count_by_group
    r = nil
    if grouped?
      begin
        # Rails3 will raise an (unexpected) RecordNotFound if there's only a nil group value
        r = Issue.visible.
          joins(:status, :project).
          where(statement).
          joins(joins_for_order_statement(group_by_statement)).
          group(group_by_statement).
          count
      rescue ActiveRecord::RecordNotFound
        r = {nil => issue_count}
      end
      c = group_by_column
      if c.is_a?(QueryCustomFieldColumn)
        r = r.keys.inject({}) {|h, k| h[c.custom_field.cast_value(k)] = r[k]; h}
      end
    end
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the issues
  # Valid options are :order, :offset, :limit, :include, :conditions
  def issues(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    scope = Issue.visible.
      joins(:status, :project).
      where(statement).
      includes(([:status, :project] + (options[:include] || [])).uniq).
      where(options[:conditions]).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      limit(options[:limit]).
      offset(options[:offset])

    scope = scope.preload(:custom_values)
    if has_column?(:author)
      scope = scope.preload(:author)
    end

    issues = scope.all

    if has_column?(:spent_hours)
      Issue.load_visible_spent_hours(issues)
    end
    if has_column?(:relations)
      Issue.load_visible_relations(issues)
    end
    issues
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the issues ids
  def issue_ids(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    Issue.visible.
      joins(:status, :project).
      where(statement).
      includes(([:status, :project] + (options[:include] || [])).uniq).
      where(options[:conditions]).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      limit(options[:limit]).
      offset(options[:offset]).
      find_ids
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the journals
  # Valid options are :order, :offset, :limit
  def journals(options={})
    Journal.visible.
      joins(:issue => [:project, :status]).
      where(statement).
      order(options[:order]).
      limit(options[:limit]).
      offset(options[:offset]).
      preload(:details, :user, {:issue => [:project, :author, :tracker, :status]}).
      all
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the versions
  # Valid options are :conditions
  def versions(options={})
    Version.visible.
      where(project_statement).
      where(options[:conditions]).
      includes(:project).
      all
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def sql_for_watcher_id_field(field, operator, value)
    db_table = Watcher.table_name
    "#{Issue.table_name}.id #{ operator == '=' ? 'IN' : 'NOT IN' } (SELECT #{db_table}.watchable_id FROM #{db_table} WHERE #{db_table}.watchable_type='Issue' AND " +
      sql_for_field(field, '=', value, db_table, 'user_id') + ')'
  end

  def sql_for_member_of_group_field(field, operator, value)
    if operator == '*' # Any group
      groups = Group.all
      operator = '=' # Override the operator since we want to find by assigned_to
    elsif operator == "!*"
      groups = Group.all
      operator = '!' # Override the operator since we want to find by assigned_to
    else
      groups = Group.where(:id => value).all
    end
    groups ||= []

    members_of_groups = groups.inject([]) {|user_ids, group|
      user_ids + group.user_ids + [group.id]
    }.uniq.compact.sort.collect(&:to_s)

    '(' + sql_for_field("assigned_to_id", operator, members_of_groups, Issue.table_name, "assigned_to_id", false) + ')'
  end

  def sql_for_assigned_to_role_field(field, operator, value)
    case operator
    when "*", "!*" # Member / Not member
      sw = operator == "!*" ? 'NOT' : ''
      nl = operator == "!*" ? "#{Issue.table_name}.assigned_to_id IS NULL OR" : ''
      "(#{nl} #{Issue.table_name}.assigned_to_id #{sw} IN (SELECT DISTINCT #{Member.table_name}.user_id FROM #{Member.table_name}" +
        " WHERE #{Member.table_name}.project_id = #{Issue.table_name}.project_id))"
    when "=", "!"
      role_cond = value.any? ?
        "#{MemberRole.table_name}.role_id IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")" :
        "1=0"

      sw = operator == "!" ? 'NOT' : ''
      nl = operator == "!" ? "#{Issue.table_name}.assigned_to_id IS NULL OR" : ''
      "(#{nl} #{Issue.table_name}.assigned_to_id #{sw} IN (SELECT DISTINCT #{Member.table_name}.user_id FROM #{Member.table_name}, #{MemberRole.table_name}" +
        " WHERE #{Member.table_name}.project_id = #{Issue.table_name}.project_id AND #{Member.table_name}.id = #{MemberRole.table_name}.member_id AND #{role_cond}))"
    end
  end

  def sql_for_is_private_field(field, operator, value)
    op = (operator == "=" ? 'IN' : 'NOT IN')
    va = value.map {|v| v == '0' ? connection.quoted_false : connection.quoted_true}.uniq.join(',')

    "#{Issue.table_name}.is_private #{op} (#{va})"
  end

  def sql_for_relations(field, operator, value, options={})
    relation_options = IssueRelation::TYPES[field]
    return relation_options unless relation_options

    relation_type = field
    join_column, target_join_column = "issue_from_id", "issue_to_id"
    if relation_options[:reverse] || options[:reverse]
      relation_type = relation_options[:reverse] || relation_type
      join_column, target_join_column = target_join_column, join_column
    end

    sql = case operator
      when "*", "!*"
        op = (operator == "*" ? 'IN' : 'NOT IN')
        "#{Issue.table_name}.id #{op} (SELECT DISTINCT #{IssueRelation.table_name}.#{join_column} FROM #{IssueRelation.table_name} WHERE #{IssueRelation.table_name}.relation_type = '#{connection.quote_string(relation_type)}')"
      when "=", "!"
        op = (operator == "=" ? 'IN' : 'NOT IN')
        "#{Issue.table_name}.id #{op} (SELECT DISTINCT #{IssueRelation.table_name}.#{join_column} FROM #{IssueRelation.table_name} WHERE #{IssueRelation.table_name}.relation_type = '#{connection.quote_string(relation_type)}' AND #{IssueRelation.table_name}.#{target_join_column} = #{value.first.to_i})"
      when "=p", "=!p", "!p"
        op = (operator == "!p" ? 'NOT IN' : 'IN')
        comp = (operator == "=!p" ? '<>' : '=')
        "#{Issue.table_name}.id #{op} (SELECT DISTINCT #{IssueRelation.table_name}.#{join_column} FROM #{IssueRelation.table_name}, #{Issue.table_name} relissues WHERE #{IssueRelation.table_name}.relation_type = '#{connection.quote_string(relation_type)}' AND #{IssueRelation.table_name}.#{target_join_column} = relissues.id AND relissues.project_id #{comp} #{value.first.to_i})"
      end

    if relation_options[:sym] == field && !options[:reverse]
      sqls = [sql, sql_for_relations(field, operator, value, :reverse => true)]
      sql = sqls.join(["!", "!*", "!p"].include?(operator) ? " AND " : " OR ")
    end
    "(#{sql})"
  end

  IssueRelation::TYPES.keys.each do |relation_type|
    alias_method "sql_for_#{relation_type}_field".to_sym, :sql_for_relations
  end
end