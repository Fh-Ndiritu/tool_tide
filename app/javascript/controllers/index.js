// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from 'controllers/application';
import { eagerLoadControllersFrom } from '@hotwired/stimulus-loading';

// stimulus components
import Dropdown from '@stimulus-components/dropdown';
import PasswordVisibility from '@stimulus-components/password-visibility';

eagerLoadControllersFrom('controllers', application);
application.register('dropdown', Dropdown);
application.register('password-visibility', PasswordVisibility);
