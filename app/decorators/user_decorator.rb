class UserDecorator < SimpleDelegator
  def icon_letters
    names = name.presence || user_name.presence || email
    if names.include?(' ')
      names.split(' ').take(2).map{_1.first}.join.upcase
    else
      names[..1].upcase
    end
  end
end
