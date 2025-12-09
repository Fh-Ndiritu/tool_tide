import { application } from 'controllers/application';
import { eagerLoadControllersFrom } from '@hotwired/stimulus-loading';
import PasswordVisibility from '@stimulus-components/password-visibility';

eagerLoadControllersFrom('controllers', application);
application.register('password-visibility', PasswordVisibility);
