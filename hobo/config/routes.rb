Rails.application.routes.draw do

  get 'dryml/:action', :controller => 'dryml_support', :as => 'dryml_support'
  # The developer's user changer: become somebody else in one click, which is
  # what makes the permissions of piece 4 worth writing -- you declare
  # `view_permitted?` and then you *look*, as each person.
  #
  # Three locks, and they are not redundant: the route only exists outside
  # production, the flag has to be on, and the controller checks again. A way
  # to become any user must be impossible to switch on by accident.
  if Rails.application.config.hobo.developer_features && !Rails.env.production?
    get 'dev/user' => 'dev#set_current_user', :as => 'hobo_dev_user'
  end

end
