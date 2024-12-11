TODO

- [X] copy over the .env files
- [X] more granular functions for file syncing
- [ ] do the build process if container not running already (would jenkins do that instead?)
- [ ] ask for ssh passphrase once/get ssh credentials in a conventient way
- [ ] sync the .env files over too
- [ ] make django do a collectstatic --clean before syncing static files
- [ ] granular execution through args passed to script
- [ ] better description of script at the top
- [ ] add docker system prune -a docker builder prune
- [ ] add compose restart function
- [ ] granular db syncing using django fixtures
- [ ] function to back up the whole server ? how do we do regular backups?
- [ ] do I run jenkins in a docker container?
- [ ] wrap risky functions in confirm()
- [ ] make basic github repo for my dotfiles(for setting up an environment for vps')
- [ ] fresh server preparation should be its own separate script that gets uploaded to the vps and ran?
- [ ] pwgen to generate pwd for vps user
- [ ] function to prepare fresh server
- [ ]
- [X] add confirm()
- [X] put up on github