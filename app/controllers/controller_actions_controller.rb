class ControllerActionsController < ApplicationController
  # GET /controller_actions
  # GET /controller_actions.xml
  before_filter :redirect_to_clean_url
  if RAILS_ENV=="development"
    before_filter :print_params
  end

  def auto_complete_for_controller_action_page
    prepare_params
    re = /#{params[:controller_action][:page]}/
    @pages = @klazz.distinct_pages.select {|name| name =~ re}

    render :inline => "<%= content_tag(:ul, @pages.map { |page| content_tag(:li, page) }) %>"
  end

  def index
    @dataset = dataset_from_params
    @plot = Plot.new(@dataset, :png)

    respond_to do |format|
      format.html { render :template => "/controller_actions/index.html.erb" }
      format.xml  { render :xml => @controller_actions }
    end
  end
  
  def enlarged_plot
    @dataset = dataset_from_params
    @plot = Plot.new(@dataset, :svg)
  end
  
  def request_time_distribution
    @dataset = dataset_from_params
    @dataset.plot_kind = :request_time_distribution
    @plot = Plot.new(@dataset, :svg)
  end

  def allocated_objects_distribution
    @dataset = dataset_from_params
    @dataset.plot_kind = :allocated_objects_distribution
    @plot = Plot.new(@dataset, :svg)
  end

  def allocated_size_distribution
    @dataset = dataset_from_params
    @dataset.plot_kind = :allocated_size_distribution
    @plot = Plot.new(@dataset, :svg)
  end

  private
  def default_date
    ControllerAction.log_data_dates.first.to_date rescue Date.yesterday
  end

  def prepare_params
    @starts_at = "#{params['year']}-#{params['month']}-#{params['day']}".to_date unless params[:year].blank?
    @starts_at = (@starts_at.blank? ? default_date : @starts_at).beginning_of_day
    @ends_at = @starts_at.end_of_day
    @klazz =  ControllerAction.class_for_date(@starts_at.to_s(:db))
    params[:resource] ||= 'total_time'
    params[:grouping] ||= 'page'
    params[:grouping_function] ||= 'sum'
    @plot_kind = Resource.resource_type(params[:resource])
    @attributes = Resource.resources_for_type(@plot_kind) - ['1']
  end

  def dataset_from_params
    prepare_params
    @hosts = @klazz.distinct_hosts
    @response_codes = @klazz.distinct_response_codes

    @page = params[:controller_action] ? params[:controller_action][:page] : nil
    params[:controller_action] = {:page => @page}
    params[:interval] ||= '5'

    FilteredDataset.new(:class => @klazz,
                        :starts_at => @starts_at,
                        :ends_at => @ends_at,
                        :interval_duration => params[:interval].to_i,
                        :user_id => params[:user_id],
                        :host => params[:server],
                        :page => @page,
                        :response_code => params[:response],
                        :heap_growth_only => params[:heap_growth_only],
                        :plot_kind => @plot_kind,
                        :resource => params[:resource] || :total_time,
                        :grouping => params[:grouping],
                        :grouping_function => (params[:grouping_function] || :avg).to_sym)
  end

  def redirect_to_clean_url
    if params[:starts_at] =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/
      redirect_to({:controller => controller_name, :action => params[:action], :year => $1, :month => $2, :day => $3,
                    :server => params[:server], :controller_action => params[:controller_action], :response => params[:response],
                    :heap_growth_only => params[:heap_growth_only], :resource => params[:resource], :grouping => params[:grouping],
                    :grouping_function => params[:grouping_function], :interval => params[:interval], :user_id => params[:user_id]}.reject{|k,v| v.blank?})
    end
  end

  def print_params
    p params
  end
end
