# ---+ Security and Authentication
# ---++ Login
# ---+++ UnixUsersContrib
# To use UnixUserMapping, you need to set the following settings in the "Security Setup" above
# <ol><li>
# UserMappingManager = 'Foswiki::Users::UnixUserMapping';
# </li><li>
# LoginManager = 'Foswiki::LoginManager::TemplateLogin';
# </li></ol>

# **STRING**
# Filter to be used to find groups.
$Foswiki::cfg{UnixUsersContrib}{GroupFilter} = '^wiki';

# **BOOLEAN**
# Enable/disable debug output to STDERR.
$Foswiki::cfg{UnixUsersContrib}{Debug} = 0;
