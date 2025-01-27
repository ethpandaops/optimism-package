# BATS (bash automated testing system) is a binary installed using git submodules
# 
# Since the path to the binary is wild, we alias it for ease of use
bats *args="":
  ./test/e2e/lib/bats/bin/bats {{args}}

test-e2e:
  just bats test/e2e/tests/*.bats