# app/helpers/iframe_helper.rb
module IframeHelper
  def render_iframe_html(text:, file_name:)
    # Render the content partial, passing locals
    content_partial_html = render(
      partial: 'shared/iframes/dynamic_iframe_content',
      locals: { html_snippet: text, file_name: file_name }
    )

    # Render the iframe layout, passing the content of the partial as the block for yield
    # This is the trick: rendering a partial *as a layout* and passing a block
    ApplicationController.render(
      layout: 'shared/_iframe_layout',
      html: content_partial_html # Use html: to pass the string content
    )
  end
end
