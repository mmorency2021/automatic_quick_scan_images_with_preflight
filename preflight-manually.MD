``` bash
# echo $XDG_RUNTIME_DIR
  echo $XDG_RUNTIME_DIR 
  cat  /run/user/1000/containers/auth.json 
 1015  preflight check container quay.samsung.bos2.lab/samsung_5gc/25a/integ-core/global-nf-mls:SVR25A_20241022_9208240 --loglevel debug -d k/run/user/1000/containers/auth.json
 1016  preflight check container quay.samsung.bos2.lab/samsung_5gc/25a/integ-core/global-nf-mls:SVR25A_20241022_9208240 --loglevel debug -d /run/user/1000/containers/auth.json
 1017  clear
 1018  ls- ltr
 1019  ls -ltr
 1020  rm preflight.log 
 1021  preflight check container quay.samsung.bos2.lab/samsung_5gc/25a/integ-core/global-nf-mls:SVR25A_20241022_9208240 --loglevel debug -d /run/user/1000/containers/auth.json
 1022  ls -ltr
 1023  cp preflight.log preflight.log.nf-mls
 1024  ls -ltr
 1025  rm preflight.log
 1026  preflight check container quay.samsung.bos2.lab/samsung_5gc/25a/integ-core/global-nf-lem:SVR25A_20241022_9208240  --loglevel debug -d /run/user/1000/containers/auth.json
 1027  ls -ltr
 1028  cp preflight.log preflight.log.nf-lem
