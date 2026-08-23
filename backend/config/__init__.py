import pymysql

# PyMySQL en remplacement de mysqlclient (évite la compilation de libs
# natives — plus simple à déployer sur Windows en dev comme sur le VPS en
# prod). Doit s'installer avant tout import du backend MySQL de Django,
# donc ici plutôt que dans settings.py.
pymysql.install_as_MySQLdb()
