<?php
$method = $_SERVER['REQUEST_METHOD'];
$url = $_SERVER['REQUEST_URI'];
error_log("request: $method $url");

if ($method == "GET") {
  $reply = "\x12\01Hi there - from the PHP server!\x12\x00\x80";
  if ($url == "/7") {
    echo base64_encode($reply);
    return;
  }
  echo $reply;
  return;
} else {
  $body = file_get_contents('php://input');
  error_log(hex_dump($body));
  echo "thank you";
}

function hex_dump($data, $newline="\n")
{
  static $from = '';
  static $to = '';

  static $width = 16; # number of bytes per line

  static $pad = '.'; # padding for non-visible characters

  if ($from==='') {
    for ($i=0; $i<=0xFF; $i++) {
      $from .= chr($i);
      $to .= ($i >= 0x20 && $i <= 0x7E) ? chr($i) : $pad;
    }
  }

  $hex = str_split(bin2hex($data), $width*2);
  $chars = str_split(strtr($data, $from, $to), $width);

  $offset = 0;
  foreach ($hex as $i => $line) {
    error_log(sprintf('%6X',$offset).' : '.implode(' ', str_split($line,2)) . ' |' . $chars[$i] . '|');
    $offset += $width;
  }
}

?>
