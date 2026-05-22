# Зависимости
sudo apt-get install -y python3 python3-dev libssl-dev libacl1-dev liblz4-dev libzstd-dev libxxhash-dev gcc build-essential pkg-config

# Скачивание и сборка
wget https://github.com/borgbackup/borg/releases/download/1.2.8/borgbackup-1.2.8.tar.gz
tar -xzf borgbackup-1.2.8.tar.gz
cd borgbackup-1.2.8
sudo python3 setup.py install
