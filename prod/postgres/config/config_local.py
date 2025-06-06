AUTHENTICATION_SOURCES = ['oauth2', 'internal']
OAUTH2_AUTO_CREATE_USER = True
OAUTH2_CONFIG = [{
	'OAUTH2_NAME' : 'authentik',
	'OAUTH2_DISPLAY_NAME' : 'authentik Identity',
	'OAUTH2_CLIENT_ID' : '<your-client-id-here>',
	'OAUTH2_CLIENT_SECRET' : '<your-client-secret-here>',
	'OAUTH2_TOKEN_URL' : 'https://identity.example.com/application/o/token/',
	'OAUTH2_AUTHORIZATION_URL' : 'https://identity.example.com/application/o/authorize/',
	'OAUTH2_API_BASE_URL' : 'https://identity.example.com/',
	'OAUTH2_USERINFO_ENDPOINT' : 'https://identity.example.com/application/o/userinfo/',
	'OAUTH2_SERVER_METADATA_URL' : 'https://identity.example.com/application/o/pgadmin/.well-known/openid-configuration',
	'OAUTH2_SCOPE' : 'openid email profile',
	'OAUTH2_ICON' : 'fa-openid',
	'OAUTH2_BUTTON_COLOR' : '#fd4b2d'
}]
