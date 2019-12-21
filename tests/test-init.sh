../init.fif 0 gamble
read -p "Send 1 Gram to the non-bouncable address above and press [Enter] to continue"
../../build/lite-client/lite-client  -C ../../ton-lite-client-test1.config.json -c"sendfile gamble-init-query.boc"