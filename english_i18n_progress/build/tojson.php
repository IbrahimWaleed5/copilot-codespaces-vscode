<?php
$d = json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR);
$code = "<?php\n\n// Auto-generated English dictionary: Arabic phrase => English. Do not edit by hand.\n// Generated from english_i18n_progress/tr (" . count($d) . " entries).\n\nreturn " . var_export($d, true) . ";\n";
file_put_contents($argv[2], $code);
