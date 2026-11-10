<?php
// ~200ms of "work" so docker stop always lands mid-flight (issue #24).
usleep(200000);
echo "ok";
