jtauth - Minetest 0.4 mod for autentification handling
===========

Drop-in replacement for default authentication handler,
intended to be able to handle large (~100MB) datasets.
Imports existing logins from auth.txt and store them on disk
in key-value storage (something in between plain text file and real database).

Depends on my library mod "jtdb" for persistent data storage.
Additional bonus: when auth.jtdb is in "maintained" state,
it's structure exactly matches auth.txt structure.

Inspired by this alternative auth handler
https://forum.minetest.net/viewtopic.php?f=9&t=18604
but in attempt to do it in pure lua way.

After job was done, i realized there is this very functional mod:
https://forum.minetest.net/viewtopic.php?t=20393
amazing work from sorcerykid.

Created by using this documentation
https://dev.minetest.net/minetest.register_authentication_handler
