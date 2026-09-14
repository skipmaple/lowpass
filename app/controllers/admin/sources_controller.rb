# 信息源（PRD 5.3）：列表、新建、编辑。启停在 Admin::Sources::EnablementsController，测试抓取在 Admin::Sources::TestFetchesController
class Admin::SourcesController < Admin::BaseController
  before_action :set_source, only: [ :edit, :update ]

  def index
    rows = Source.admin_rows
    render inertia: "Admin/Sources/Index", props: {
      sources: rows,
      summary: "#{rows.size} 个来源 · #{rows.count { |r| r[:publication] == "daily" }} 个日刊 · #{rows.count { |r| r[:publication] == "weekly" }} 个周刊"
    }
  end

  def new
    render_form(Source.new(adapter: "rss", publication: "daily", sort_order: Source.maximum(:sort_order).to_i + 1))
  end

  def create
    source = Source.new(source_params)
    if source.save
      Audit.record("source.create", "Source##{source.id}", source.slice(:name, :adapter, :publication, :sort_order, :config))
      redirect_to admin_sources_path, notice: "已保存 #{source.name}"
    else
      redirect_to new_admin_source_path, inertia: { errors: source.errors.to_hash }
    end
  end

  def edit
    render_form(@source)
  end

  # R-3.4 修改立即生效于下一次抓取；适配器不可改（设计 A9）
  def update
    if @source.update(source_params.except(:adapter))
      Audit.record("source.update", "Source##{@source.id}", @source.saved_changes.except("updated_at"))
      redirect_to admin_sources_path, notice: "已保存 #{@source.name}"
    else
      redirect_to edit_admin_source_path(@source), inertia: { errors: @source.errors.to_hash }
    end
  end

  private
    def set_source
      @source = Source.find(params[:id])
    end

    def source_params
      params.require(:source).permit(:name, :adapter, :publication, :sort_order, config: {})
    end

    def render_form(source)
      render inertia: "Admin/Sources/Form", props: { source: source.form_props, adapters: Source.adapter_options }
    end
end
