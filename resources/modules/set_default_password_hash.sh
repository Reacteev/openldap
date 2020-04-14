#!/bin/bash

echo "Setting PBKDF2-SHA512 as default password hash..."

ldapmodify -Y EXTERNAL -H ldapi:/// << END
dn: olcDatabase={-1}frontend,cn=config
add: olcPasswordHash
olcPasswordHash: {PBKDF2-SHA512}
END

echo "Done."

