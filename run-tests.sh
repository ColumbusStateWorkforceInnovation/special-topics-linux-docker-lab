#########
######### You can run this script to test your shell script.  Reading through it you
######### will also be able to see the kind of behavior your script is expected to
######### produce.
#########
######### Note: this assumes you name your container "my-apache-app".  If you choose a
#########       different name then change the next line appropriately
CNAME="my-apache-app"

set +H
function error {
  echo ""
  echo "ERROR: $1"
  exit 1
}

function cleanup {
  docker rm -f ${CNAME}  >/dev/null 2>&1
  $(curl http://localhost:8080 >/dev/null 2>&1) && error "You have something running on port 8080 - please stop it first!"
 
} 

function check_running {
  url=$1
  ((t=0))
  while [ $t -lt 5 ]
  do
    ((t++))
    $(curl $url >/dev/null 2>&1) && return 0    
    echo "wait a bit for the server to start..."
    sleep 5
  done
  return 1 
}

function test_url {
  url=$1
  expected="It works"
  [[ $# -eq 2 ]] && expected=$2
  
  check_running $url || error "The server never came up at $url"
 
  echo "Checking $url output..."
  curl -s $url > /tmp/$$
  rc=$?
  [[ $rc -ne 0 ]] && error "error trying to fetch $url"
  grep "$expected" /tmp/$$ >/dev/null || error "couldn't find: [$expected] in \n[$(cat /tmp/$$)]"
}
  

APP="httpd-ctl.sh"

echo "checking the script exists and is executable..."
[[ ! -f bin/$APP ]] && error "I couldn't find a file \"bin/$APP\"!"
[[ ! -x bin/$APP ]] && error "\"bin/$APP\" is not marked executable!"

echo "stopping anything that's already running..."
cleanup
PATH=$PATH:$PWD/bin

echo ""
echo "Test 1: Basic start command"
$APP start
test_url "http://localhost:8080"

echo ""
echo "Test 2: Basic stop command"
$APP stop
curl -s "http://localhost:8080" >/dev/null && error "$APP stop didn't stop the container!"
status=$(docker container inspect -f '{{.State.Status}}' ${CNAME})
[[ $status -eq "exited" ]] || error "Container isn't in exited state!  Did you remove it?"

docker rm ${CNAME}

echo ""
echo "Test 3: Start on a different port"
$APP -p 9988 start
test_url "http://localhost:9988"

echo ""
echo "Test 4: Basic destroy command"
$APP destroy
curl -s "http://localhost:9988" >/dev/null && error "$APP destroy didn't stop the container!"
docker container inspect -f '{{.State.Status}}' ${CNAME} >/dev/null 2>&1
[[ $? -eq 1 ]] || error "$APP destroy didn't remove the container!!  Here's what I see on your system:\n$(docker ps -a)"

echo ""
echo "Test 5: Volume mount a directory"
$APP -d $PWD/www start
test_url "http://localhost:8080" "Welcome to Special Topics"
docker rm -f ${CNAME}

echo ""
echo "Test 6: Test both options"
$APP -p 8991 -d $PWD/www  start
test_url "http://localhost:8991" "Welcome to Special Topics"
docker rm -f ${CNAME}

echo ""
echo "Test 7: options are swappable"
$APP -d $PWD/www -p 9123  start
test_url "http://localhost:9123" "Welcome to Special Topics"
docker rm -f ${CNAME}
