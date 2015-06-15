/vagrant/source/memex/settings.py:
  file.copy:
    - source: /vagrant/source/memex/settings_files/deploy_settings.py
    - user: vagrant
    - force: True

LOCAL_PATH:
  file.append:
    - name: /home/vagrant/.bashrc
    - text: export PATH="/home/vagrant/miniconda/envs/memex/bin:$PATH"

local_settings_path:
   environ.setenv:
     - name: LOCAL_SETTINGS_PATH
     - value: /vagrant/source/memex/local_settings.py


# TODO: The create_apps_Tika_ES_Kibana is not idempotent.  This needs
# to be fixed or the command needs to be protected so that it only
# executes when the applications need to be created.
# As a workaround, the SQL database is currently reset on each provision.

reset:
  file.absent:
    - name: /vagrant/source/db.sqlite3

migrate:
  cmd.run:
    - name: |
        /home/vagrant/miniconda/envs/memex/bin/python /vagrant/source/manage.py migrate
    - cwd: /home/vagrant
    - user: vagrant
    - require:
        - sls: conda-memex

collectstatic:
  cmd.run:
    - name: |
        echo yes | /home/vagrant/miniconda/envs/memex/bin/python /vagrant/source/manage.py collectstatic
    - cwd: /home/vagrant
    - user: vagrant
    - require:
        - sls: conda-memex

refresh_nginx:
  cmd.run:
    - name: |
        /home/vagrant/miniconda/envs/memex/bin/python /vagrant/source/manage.py refresh_nginx
    - cwd: /home/vagrant
    - user: vagrant
    - require:
        - sls: conda-memex

create_apps:
  cmd.run:
    - name: |
        /home/vagrant/miniconda/envs/memex/bin/python /vagrant/source/manage.py create_apps_Tika_ES_Kibana
    - cwd: /home/vagrant
    - user: vagrant
    - require:
        - sls: conda-memex

celery:
  cmd.run:
    - name: /home/vagrant/miniconda/envs/memex/bin/celery --detach --loglevel=debug --logfile=/vagrant/source/celeryd.log --workdir="/vagrant/source" -A memex worker
    - cwd: /vagrant/source
    - user: vagrant
    - env:
        - JAVA_HOME: '/usr/lib/jvm/java-7-oracle'
    - unless: "ps -p $(cat /vagrant/source/celeryd.pid)"
    - require:
        - sls: conda-memex

supervisor:
  cmd.run:
    - name: |
        source activate memex
        supervisord -c /vagrant/deploy/supervisor.conf        
    - user: vagrant
    - env:
       - PATH:
           /home/vagrant/miniconda/bin:/home/ubuntu/miniconda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
    - require:
        - sls: conda-memex
    - unless: test -e /home/vagrant/gunicorn_supervisor.sock

reload-supervisor:
  cmd.run:
    - name: |
        source activate memex
        supervisorctl -c /vagrant/deploy/supervisor.conf reload
    - user: vagrant
    - env:
       - PATH:
           /home/vagrant/miniconda/bin:/home/ubuntu/miniconda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
    - require:
        - sls: conda-memex
