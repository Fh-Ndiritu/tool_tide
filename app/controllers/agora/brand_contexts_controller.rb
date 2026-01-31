# frozen_string_literal: true

module Agora
  class BrandContextsController < ApplicationController
    layout "agora/application"

    def index
      @brand_contexts = Agora::BrandContext.all.order(:key)
      @website_context = @brand_contexts.find_by(key: "website.md")
      @llms_txt = @brand_contexts.find_by(key: "llms.txt")
      @llms_full_txt = @brand_contexts.find_by(key: "llms-full.txt")
    end

    def create
      website_url = params[:website_url]
      llms_txt_url = params[:llms_txt_url].presence
      llms_full_txt_url = params[:llms_full_txt_url].presence

      if website_url.blank?
        redirect_to agora_brand_contexts_path, alert: "Website URL is required"
        return
      end

      # Enqueue the crawl job (delete_all happens atomically in the job)
      Agora::SiteCrawlJob.perform_later(
        website_url: website_url,
        llms_txt_url: llms_txt_url,
        llms_full_txt_url: llms_full_txt_url
      )

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "brand_context_status",
            partial: "agora/shared/flash_message",
            locals: { type: :notice, message: "🚀 Site crawl queued for #{website_url}..." }
          )
        end
        format.html { redirect_to agora_brand_contexts_path, notice: "Site crawl started! Refresh in a few moments." }
      end
    end

    def download
      context = Agora::BrandContext.find(params[:id])
      filename = context.key.ends_with?(".md") ? context.key.sub(".md", ".txt") : context.key

      send_data context.raw_content,
                filename: filename,
                type: "text/plain",
                disposition: "attachment"
    end
  end
end
