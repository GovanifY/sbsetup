#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root"
  exit
fi

echo "Please ensure your Secure Boot is in setup mode before continuing!"
read
echo "Please install gcc and libelf before continuing!"
read
echo -n "Enter a Common Name to embed in the keys: "
read NAME

pushd
TEMP=$(mktemp -d)
cd $TEMP

openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME PK/" -keyout PK.key \
        -out PK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME KEK/" -keyout KEK.key \
        -out KEK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME DB/" -keyout db.key \
        -out db.crt -days 3650 -nodes -sha256
openssl x509 -in PK.crt -out PK.cer -outform DER
openssl x509 -in KEK.crt -out KEK.cer -outform DER
openssl x509 -in db.crt -out db.cer -outform DER

GUID=`python3 -c 'import uuid; print(str(uuid.uuid1()))'`
echo $GUID > myGUID.txt

cert-to-efi-sig-list -g $GUID PK.crt PK.esl
cert-to-efi-sig-list -g $GUID KEK.crt KEK.esl
cert-to-efi-sig-list -g $GUID db.crt db.esl
rm -f noPK.esl
touch noPK.esl

sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK noPK.esl noPK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt KEK KEK.esl KEK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k KEK.key -c KEK.crt db db.esl db.auth

chmod 0600 *.key

mkdir -p /etc/secureboot/keys/{PK,KEK,db,dbx}
mv PK* /etc/secureboot/keys/PK/
mv KEK* /etc/secureboot/keys/KEK/
mv db* /etc/secureboot/keys/db/
efi-updatevar -e -f /etc/secureboot/keys/db/db.esl db
efi-updatevar -e -f /etc/secureboot/keys/KEK/KEK.esl KEK
efi-updatevar -f /etc/secureboot/keys/PK/PK.auth PK

git clone --recursive https://github.com/rhboot/shim/
cd shim
make VENDOR_CERT_FILE=/etc/secureboot/keys/db/db.cer REQUIRE_TPM=y EFIDIR=signed install
cp -rf /boot/efi/EFI/signed/shimx64.efi /etc/secureboot/shimx64.efi 
cp -rf /boot/efi/EFI/signed/mmx64.efi /etc/secureboot/mmx64.efi
sbsign --key /etc/secureboot/keys/db/db.key --cert /etc/secureboot/keys/db/db.crt --output /etc/secureboot/shimx64.efi /etc/secureboot/shimx64.efi
sbsign --key /etc/secureboot/keys/db/db.key --cert /etc/secureboot/keys/db/db.crt --output /etc/secureboot/mmx64.efi /etc/secureboot/mmx64.efi

cat >/etc/grub.d/40_custom <<EOF
#!/bin/sh
grub-install --bootloader-id=signed >/dev/null 2>&1
sbattach --remove /boot/efi/EFI/signed/grubx64.efi
sbsign --key /etc/secureboot/keys/db/db.key --cert /etc/secureboot/keys/db/db.crt --output /boot/efi/EFI/signed/grubx64.efi /boot/efi/EFI/signed/grubx64.efi
cp -rf /etc/secureboot/shimx64.efi /boot/efi/EFI/signed/shimx64.efi
cp -rf /etc/secureboot/mmx64.efi /boot/efi/EFI/signed/mmx64.efi
find /boot -type f -not -path "/boot/efi" -iname '*vmlinuz*' -execdir sbattach --remove {} \;
find /boot -type f -not -path "/boot/efi" -iname '*vmlinuz*' -execdir sbsign --key /etc/secureboot/keys/db/db.key --cert /etc/secureboot/keys/db/db.crt --output {} {} \;
EOF

grub-mkconfig -o /boot/grub/grub.cfg

popd

echo "Done! You may now reboot; make sure to setup a strong password to your UEFI :)"
