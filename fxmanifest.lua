fx_version 'cerulean'
game 'gta5'

description 'Baba_Mechanic V.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts { 'client.lua' }
server_scripts { 'server.lua' }

dependencies {
    'ox_inventory',
    'ox_lib'
}
