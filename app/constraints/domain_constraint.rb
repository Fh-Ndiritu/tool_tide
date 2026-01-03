# frozen_string_literal: true

class DomainConstraint
  def initialize(domain)
    @domains = [ domain ].flatten
  end

  def matches?(request)
    @domains.any? { |d| request.host.include?(d) }
  end
end
