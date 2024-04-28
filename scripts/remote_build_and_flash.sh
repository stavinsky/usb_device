set -e
rsync -avz . rev@192.168.88.246:tmp/
ssh rev@192.168.88.246 'cd /home/rev/tmp && ~/Downloads/IDE/bin/gw_sh build.tcl'
scp -r rev@192.168.88.246:/home/rev/tmp/impl/pnr/project.fs build/
openFPGALoader -b tangnano9k build/project.fs