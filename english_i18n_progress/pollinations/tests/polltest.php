<?php
// Pollinations integration tests (all HTTP faked: no pollen spent).
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
foreach (['AssistantSettingsService','PlatformAiContextService','ProjectFileAccessService','ProjectFileVersionService','SupportBotService'] as $c) { if (!class_exists("App\\Services\\$c")) eval("namespace App\\Services; class $c {}"); }
foreach (['AiArtifactBuilder','AiCodeArtifactBuilder','ProjectAgentContextService','AiAgentActionService'] as $c) { if (!class_exists("App\\Services\\AiAgent\\$c")) eval("namespace App\\Services\\AiAgent; class $c {}"); }
if (!class_exists('App\Models\Project')) eval('namespace App\Models; class Project {}');
if (!class_exists('App\Exceptions\AiCreditsExhaustedException')) eval('namespace App\Exceptions; class AiCreditsExhaustedException extends \Exception { public $entitlement = []; }');

use App\Exceptions\PollinationsException;
use App\Models\AiGeneration;
use App\Services\PollinationsService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\{Http, Storage, Schema, Cache, DB, Log, RateLimiter};

config(['database.default'=>'sqlite','database.connections.sqlite.database'=>':memory:','cache.default'=>'array','filesystems.disks.local.root'=>sys_get_temp_dir().'/polltest']);
DB::purge('sqlite');
Schema::create('support_tickets', fn($t)=>[$t->id(),$t->unsignedBigInteger('user_id')->nullable(),$t->unsignedBigInteger('project_id')->nullable(),$t->boolean('is_ai_conversation')->default(true),$t->decimal('bot_confidence')->nullable(),$t->timestamp('last_message_at')->nullable(),$t->timestamps()]);
Schema::create('support_messages', fn($t)=>[$t->id(),$t->unsignedBigInteger('support_ticket_id'),$t->unsignedBigInteger('sender_id')->nullable(),$t->string('sender_type'),$t->text('message'),$t->string('message_type')->nullable(),$t->boolean('is_internal')->default(false),$t->string('attachment_path')->nullable(),$t->string('attachment_name')->nullable(),$t->string('attachment_mime')->nullable(),$t->integer('attachment_size')->nullable(),$t->string('scan_status',20)->nullable(),$t->timestamps()]);
Schema::create('users', fn($t)=>[$t->id(),$t->string('name')->nullable(),$t->timestamps()]);
Schema::create('ai_usage_logs', fn($t)=>[$t->id(),$t->integer('credits_used')->default(0),$t->timestamps()]);
(require __DIR__.'/../aifix/database/migrations/2026_10_01_120000_create_ai_generations_table.php')->up();

$ok=0;$fail=0; function check($n,$c){global $ok,$fail; echo ($c?'PASS ':'FAIL ').$n."\n"; $c?$ok++:$fail++;}
function fresh(array $fakes){ Http::swap(new Illuminate\Http\Client\Factory()); Http::fake($fakes); Cache::flush(); }
$KEY = 'sk_test_SECRET_1234567890';
$logs = []; Log::listen(function ($e) use (&$logs) { $logs[] = $e->message . ' ' . json_encode($e->context); });
$png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
$mp4 = "\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom" . str_repeat("\x00", 2048);
$catalogue = [
  ['id'=>'tongyi-mai/z-image-turbo','aliases'=>['zimage'],'input_modalities'=>['text'],'output_modalities'=>['image'],'supported_endpoints'=>['/image/{prompt}','/v1/images/generations']],
  ['id'=>'black-forest-labs/flux.1-kontext-pro','aliases'=>['kontext'],'input_modalities'=>['text','image'],'output_modalities'=>['image'],'supported_endpoints'=>['/v1/images/generations','/v1/images/edits']],
  ['id'=>'google/veo-3.1-fast','aliases'=>['veo'],'input_modalities'=>['text','image'],'output_modalities'=>['video'],'supported_endpoints'=>['/video/{prompt}'],'paid_only'=>true],
];
$imageJson = ['created'=>1,'data'=>[['b64_json'=>base64_encode($png)]],'usage'=>['input_tokens'=>5,'output_tokens'=>1,'total_tokens'=>6]];
$base = ['pollinations.api_key'=>$KEY,'pollinations.base_url'=>'https://gen.pollinations.ai','pollinations.media_url'=>'https://media.pollinations.ai','pollinations.retries'=>1,
  'services.gemini.enabled'=>true,'services.gemini.api_key'=>'g','services.gemini.model'=>'gemini-2.5-flash',
  'ai_media.image_providers'=>['gemini','pollinations'],'ai_media.video.enabled'=>true,'ai_media.video.providers'=>['pollinations'],
  'ai_assistant.text_providers'=>['gemini','pollinations'],'ai_media.translate_prompts'=>false];
config($base);
$svc = fn() => app()->make(PollinationsService::class);
app()->singleton(App\Services\AiCreditService::class);

// ── 1. not configured ────────────────────────────────────────────────────────
config(['pollinations.api_key'=>'']); fresh([]);
check('no key -> not configured, no HTTP', !$svc()->configured() && !$svc()->supportsVideo() && count(Http::recorded())===0);
check('no key -> image chain has no pollinations', !in_array('pollinations', app(App\Services\AiAgent\ImageGenerationManager::class)->providers()));
check('no key -> text providers = gemini only', app(App\Services\GeminiSupportService::class)->textProviders() === ['gemini']);
try { $svc()->generateImage('x'); check('no key throws', false); } catch (PollinationsException $e) { check('no key -> not_configured', $e->reason==='not_configured'); }
config($base);

// ── 2. catalogue / model verification / auth header ─────────────────────────
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue)]);
$s = $svc();
check('resolve image = configured default', $s->resolveModel('image')==='tongyi-mai/z-image-turbo');
check('resolve edit needs image input + edits endpoint', $s->resolveModel('edit')==='black-forest-labs/flux.1-kontext-pro');
check('video verified from output_modalities', $s->resolveModel('video')==='google/veo-3.1-fast' && $s->supportsVideo(true));
$req = Http::recorded()[0][0];
check('auth: Bearer header, key not in URL', $req->hasHeader('Authorization','Bearer '.$KEY) && !str_contains($req->url(), $KEY));
check('catalogue cached (1 request)', ($s->resolveModel('image') && $s->resolveModel('video')) && count(Http::recorded())===1);
config(['pollinations.video_model'=>'alias-not-listed']); check('unknown configured model -> first verified', $s->resolveModel('video')==='google/veo-3.1-fast'); config($base);
fresh(['gen.pollinations.ai/image/models' => Http::response([$catalogue[0]])]);
check('no video model in catalogue -> video hidden', !$svc()->supportsVideo() && $svc()->resolveModel('video')===null);
fresh(['gen.pollinations.ai/image/models' => Http::response([], 500)]);
check('catalogue down -> image uses documented default, video off', $svc()->resolveModel('image')==='tongyi-mai/z-image-turbo' && $svc()->resolveModel('video')===null);
$n = count(Http::recorded()); $svc()->resolveModel('image');
check('catalogue down is remembered (no retry storm)', count(Http::recorded())===$n);

// ── 3. image generation ─────────────────────────────────────────────────────
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::response($imageJson)]);
$r = $svc()->generateImage('modern villa', '512x512');
$body = collect(Http::recorded())->first(fn($p)=>str_contains($p[0]->url(),'generations'))[0]->data();
check('image: b64 decoded + validated as image', $r['bytes']===$png && $r['mime']==='image/png' && $r['model']==='tongyi-mai/z-image-turbo');
check('image: documented body', $body['response_format']==='b64_json' && $body['size']==='512x512' && $body['n']===1 && $body['model']==='tongyi-mai/z-image-turbo');
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::response(['data'=>[['b64_json'=>base64_encode('<html>not an image</html>')]]])]);
try { $svc()->generateImage('x'); check('invalid image rejected', false); } catch (PollinationsException $e) { check('invalid image -> invalid_response (not saved)', $e->reason==='invalid_response'); }
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::response(['data'=>[['url'=>'https://evil.example.com/a.png']]])]);
try { $svc()->generateImage('x'); check('foreign URL not fetched', false); } catch (PollinationsException $e) { check('url outside pollinations.ai is never fetched', $e->reason==='invalid_response' && !collect(Http::recorded())->contains(fn($p)=>str_contains($p[0]->url(),'evil'))); }

// ── 4. errors ───────────────────────────────────────────────────────────────
$err = fn($status,$code,$headers=[]) => Http::response(['status'=>$status,'success'=>false,'error'=>['code'=>$code,'message'=>'upstream said '.$KEY,'requestId'=>'req_1']], $status, $headers);
$cases = [[401,'UNAUTHORIZED','auth'],[402,'PAYMENT_REQUIRED','payment'],[403,'FORBIDDEN','forbidden'],[422,'content_policy_violation','content_policy'],[400,'BAD_REQUEST','bad_request']];
foreach ($cases as [$st,$code,$reason]) {
  fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => $err($st,$code)]);
  try { $svc()->generateImage('x'); check("$st throws", false); }
  catch (PollinationsException $e) { check("$st -> $reason, safe message, no retry", $e->reason===$reason && !str_contains($e->getMessage(),$KEY) && !str_contains($e->getMessage(),'upstream said') && collect(Http::recorded())->filter(fn($p)=>str_contains($p[0]->url(),'generations'))->count()===1); }
}
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => $err(429,'RATE_LIMITED',['Retry-After'=>'42'])]);
try { $svc()->generateImage('x'); } catch (PollinationsException $e) { check('429 -> rate_limited with Retry-After', $e->reason==='rate_limited' && $e->retryAfter===42); }
$n = count(Http::recorded());
try { $svc()->generateImage('x'); } catch (PollinationsException $e) { check('429 cooldown: next call fails fast without HTTP', $e->reason==='rate_limited' && count(Http::recorded())===$n); }
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::sequence()->push(['error'=>['code'=>'SERVICE_UNAVAILABLE']],503)->push($imageJson)]);
$r = $svc()->generateImage('x');
check('503 retried once then succeeds', $r['bytes']===$png && collect(Http::recorded())->filter(fn($p)=>str_contains($p[0]->url(),'generations'))->count()===2);
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => fn() => throw new ConnectionException('cURL error 28: Operation timed out after 120001 milliseconds')]);
try { $svc()->generateImage('x'); check('timeout throws', false); } catch (PollinationsException $e) { check('timeout -> reason timeout (retried within limit)', $e->reason==='timeout' && collect(Http::recorded())->count()<=3); }
check('key never written to logs', !collect($logs)->contains(fn($l)=>str_contains($l,$KEY)) && collect($logs)->contains(fn($l)=>str_contains($l,'Pollinations request failed')));

// ── 5. image chain: Gemini fails -> Pollinations, stored in platform storage ─
$mgr = fn() => app()->make(App\Services\AiAgent\ImageGenerationManager::class);
fresh(['generativelanguage.googleapis.com/*' => Http::response(['error'=>['message'=>'quota']],429),
       'gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::response($imageJson)]);
$a = $mgr()->generate('بدي صورة واجهة فيلا', 7, 11, null, 'exterior');
check('gemini 429 -> pollinations', $a['provider']==='pollinations' && $a['model']==='tongyi-mai/z-image-turbo');
check('stored in platform storage (not an external URL)', Storage::disk('local')->exists($a['path']) && str_starts_with($a['path'],'assistant/generated/7/11/') && Storage::disk('local')->get($a['path'])===$png);
$p = collect(Http::recorded())->first(fn($p)=>str_contains($p[0]->url(),'generations'))[0]->data()['prompt'];
check('exterior style hint added to prompt', str_contains($p,'Exterior architectural rendering'));
// edit: multipart upload, file not published
$tmp = tempnam(sys_get_temp_dir(),'img'); file_put_contents($tmp,$png);
fresh(['generativelanguage.googleapis.com/*' => Http::response([],500), 'gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/edits' => Http::response($imageJson)]);
$a = $mgr()->generate('حسّن جودة الرندر', 7, 11, ['path'=>$tmp,'mime_type'=>'image/png']);
$er = collect(Http::recorded())->first(fn($p)=>str_contains($p[0]->url(),'edits'))[0];
check('edit -> /v1/images/edits multipart with kontext + enhance hint', $a['provider']==='pollinations' && $er->isMultipart() && collect($er->data())->contains(fn($f)=>($f['name']??'')==='image')
  && collect($er->data())->contains(fn($f)=>($f['name']??'')==='model' && $f['contents']==='black-forest-labs/flux.1-kontext-pro')
  && collect($er->data())->contains(fn($f)=>($f['name']??'')==='prompt' && str_contains($f['contents'],'Enhance this render'))
  && !collect(Http::recorded())->contains(fn($p)=>str_contains($p[0]->url(),'media.pollinations.ai')));

// ── 6. text: agents switch to Pollinations when Gemini is down ───────────────
$chat = fn($text) => Http::response(['choices'=>[['message'=>['role'=>'assistant','content'=>$text]]],'usage'=>['prompt_tokens'=>100,'completion_tokens'=>50,'reasoning_tokens'=>10,'total_tokens'=>150]]);
$gem = app(App\Services\GeminiSupportService::class);
fresh(['generativelanguage.googleapis.com/*' => Http::response(['error'=>['message'=>'quota']],429), 'gen.pollinations.ai/v1/chat/completions' => $chat('جواب من المزود الثاني')]);
$u = null; $t = null; $ans = $gem->answer('سؤال', '', [], '', '', null, 'chat', $u, 'smart', $t);
check('answer(): Gemini 429 -> Pollinations text', $ans==='جواب من المزود الثاني');
check('usage mapped for metered Credits', $u['model']==='pollinations:openai/gpt-5.4-nano' && $u['promptTokenCount']===100 && $u['candidatesTokenCount']===40 && $u['thoughtsTokenCount']===10 && $u['totalTokenCount']===150);
$q = app(App\Services\AiMeteredCreditPricing::class)->quote('smart', $u); check('pricing accepts Pollinations usage', $q['credits']>=1);
config(['ai_assistant.text_providers'=>['pollinations','gemini']]);
fresh(['generativelanguage.googleapis.com/*' => Http::response(['candidates'=>[['content'=>['parts'=>[['text'=>'gemini']]]]]]), 'gen.pollinations.ai/v1/chat/completions' => $chat('polli first')]);
check('AI_TEXT_PROVIDERS=pollinations,gemini -> Pollinations primary', $gem->generate('x')==='polli first' && !collect(Http::recorded())->contains(fn($p)=>str_contains($p[0]->url(),'googleapis')));
fresh(['generativelanguage.googleapis.com/*' => Http::response(['candidates'=>[['content'=>['parts'=>[['text'=>'gemini ok']]]]]]), 'gen.pollinations.ai/v1/chat/completions' => Http::response([],502)]);
check('Pollinations primary down -> Gemini', $gem->generate('x')==='gemini ok');
config(['ai_assistant.text_providers'=>['gemini','pollinations']]);
// router falls back too, so agents are still triggered
fresh(['generativelanguage.googleapis.com/*' => Http::response([],503), 'gen.pollinations.ai/v1/chat/completions' => $chat("```json\n{\"intent\":\"chat\",\"resolved_request\":\"حلل النظام\",\"save_to_project\":false,\"complex\":true,\"confidence\":0.9,\"reason\":\"\"}\n```")]);
$route = $gem->routeIntent('حلل لي معمارية النظام كاملة');
check('routeIntent(): Gemini down -> Pollinations JSON parsed', ($route['intent']??null)==='chat' && ($route['complex']??false)===true);
// full agents pipeline on Pollinations only
config(['ai_assistant.agents_max_steps'=>2]);
$plan = json_encode(['goal'=>'تحليل','steps'=>[['title'=>'تحليل المتطلبات','instruction'=>'حلل'],['title'=>'تصميم','instruction'=>'صمم']]], JSON_UNESCAPED_UNICODE);
fresh(['generativelanguage.googleapis.com/*' => Http::response(['error'=>['message'=>'down']],500),
       'gen.pollinations.ai/v1/chat/completions' => Http::sequence()->push(['choices'=>[['message'=>['content'=>$plan]]],'usage'=>['prompt_tokens'=>10,'completion_tokens'=>10,'total_tokens'=>20]])
          ->push(['choices'=>[['message'=>['content'=>'نتيجة 1']]],'usage'=>['prompt_tokens'=>10,'completion_tokens'=>10,'total_tokens'=>20]])
          ->push(['choices'=>[['message'=>['content'=>'نتيجة 2']]],'usage'=>['prompt_tokens'=>10,'completion_tokens'=>10,'total_tokens'=>20]])
          ->push(['choices'=>[['message'=>['content'=>'الجواب النهائي المراجع']]],'usage'=>['prompt_tokens'=>10,'completion_tokens'=>10,'total_tokens'=>20]])]);
$run = app(App\Services\AiAgent\AgentOrchestrator::class)->run('حلل النظام', '', [], '', '', 'engineering', 'work');
check('agents pipeline runs fully on Pollinations when Gemini is down', ($run['answer']??'')==='الجواب النهائي المراجع' && $run['steps']===2 && $run['usage']['totalTokenCount']===80);
$gp = new App\Services\AiProviders\GeminiProvider($gem); $pp = app(App\Services\AiProviders\PollinationsProvider::class);
check('AiProviderInterface implemented by both', $gp instanceof App\Contracts\AiProviderInterface && $pp instanceof App\Contracts\AiProviderInterface && $pp->name()==='pollinations' && $pp->supports('text'));

// ── 7. video: start -> processing -> completed (DB record + storage) ─────────
$ticket = App\Models\SupportTicket::create(['user_id'=>7,'project_id'=>55]);
$usage = App\Models\AiUsageLog::create([]);
$rec = app(App\Services\AiAgent\AiGenerationRecorder::class);
$gen = $rec->start(['user_id'=>7,'project_id'=>55,'support_ticket_id'=>$ticket->id,'type'=>'text_to_video','kind'=>'exterior','prompt'=>'فيديو فيلا']);
check('record created as processing', $gen && $gen->status==='processing');
$videoHits = 0; $videoUrls = [];
fresh(['generativelanguage.googleapis.com/*' => Http::response(['candidates'=>[['content'=>['parts'=>[['text'=>'Drone orbit around a villa']]]]]]),
       'gen.pollinations.ai/image/models' => Http::response($catalogue),
       'gen.pollinations.ai/video/*' => function ($rq) use (&$videoHits, &$videoUrls, $mp4) { $videoUrls[] = $rq->url(); $videoHits++; if ($videoHits === 1) throw new ConnectionException('cURL error 28: Operation timed out after 8000 milliseconds'); return Http::response($mp4, 200, ['Content-Type'=>'video/mp4']); }]);
$vs = app(App\Services\AiAgent\VideoGenerationService::class);
$started = $vs->start($ticket, 7, 'فيديو فيلا', $usage, null, $gen->id, 'exterior');
$job = Cache::get('ai_video_jobs:ticket:'.$ticket->id)[0];
check('video started at pollinations; first request timed out = still generating', $started['provider']==='pollinations' && $vs->pendingCount($ticket->id)===1);
check('job handle holds no secret', !str_contains(json_encode($job), $KEY));
parse_str(parse_url($videoUrls[0], PHP_URL_QUERY), $qq);
check('video request per docs: model, duration 6 (veo 4/6/8), aspectRatio, seed', $qq['model']==='google/veo-3.1-fast' && $qq['duration']==='6' && $qq['aspectRatio']==='16:9' && (int)$qq['seed']>0);
Cache::forget('ai_video_jobs:ticket:'.$ticket->id.':tick');
check('advance -> finished', $vs->advance($ticket)===1);
check('poll repeats the exact same request (same seed)', count($videoUrls)===2 && $videoUrls[1]===$videoUrls[0]);
$m = App\Models\SupportMessage::query()->where('support_ticket_id',$ticket->id)->latest('id')->first();
check('video posted with stored mp4', $m->attachment_mime==='video/mp4' && Storage::disk('local')->exists($m->attachment_path));
$gen->refresh();
check('record completed with provider/model/path/user/project/message', $gen->status==='completed' && $gen->provider==='pollinations' && $gen->model==='google/veo-3.1-fast' && $gen->output_path===$m->attachment_path && $gen->user_id===7 && $gen->project_id===55 && $gen->support_message_id===$m->id && $gen->completed_at);
check('credits completed for video', in_array('complete:pollinations-video', app(App\Services\AiCreditService::class)->calls));
// failure: content policy while polling -> failed record, refund, retry marker
$gen2 = $rec->start(['user_id'=>7,'support_ticket_id'=>$ticket->id,'type'=>'text_to_video','prompt'=>'x']);
$hits = 0;
fresh(['generativelanguage.googleapis.com/*' => Http::response(['candidates'=>[['content'=>['parts'=>[['text'=>'p']]]]]]), 'gen.pollinations.ai/image/models' => Http::response($catalogue),
       'gen.pollinations.ai/video/*' => function () use (&$hits, $KEY) { $hits++; if ($hits===1) throw new ConnectionException('cURL error 28: Operation timed out'); return Http::response(['status'=>422,'success'=>false,'error'=>['code'=>'content_policy_violation','message'=>'blocked']],422); }]);
$credits = app(App\Services\AiCreditService::class); $credits->calls = [];
$vs->start($ticket, 7, 'x', App\Models\AiUsageLog::create([]), null, $gen2->id);
Cache::forget('ai_video_jobs:ticket:'.$ticket->id.':tick'); $vs->advance($ticket);
$m = App\Models\SupportMessage::query()->where('support_ticket_id',$ticket->id)->latest('id')->first(); $gen2->refresh();
check('policy refusal -> failed record + safe reason + refund + retry marker', $gen2->status==='failed' && str_contains($gen2->error_message,'سياسة المحتوى') && $m->scan_status==='gen_failed' && in_array('refund:video_generation_failed', $credits->calls));
// temporary 429 while polling keeps waiting
$hits = 0;
fresh(['generativelanguage.googleapis.com/*' => Http::response(['candidates'=>[['content'=>['parts'=>[['text'=>'p']]]]]]), 'gen.pollinations.ai/image/models' => Http::response($catalogue),
       'gen.pollinations.ai/video/*' => function () use (&$hits) { $hits++; if ($hits===1) throw new ConnectionException('cURL error 28: Operation timed out'); return Http::response(['error'=>['code'=>'RATE_LIMITED']],429,['Retry-After'=>'5']); }]);
$vs->start($ticket, 7, 'x', App\Models\AiUsageLog::create([]));
Cache::forget('ai_video_jobs:ticket:'.$ticket->id.':tick'); $vs->advance($ticket);
check('429 while polling -> still pending (not failed)', $vs->pendingCount($ticket->id)===1);
Cache::forget('ai_video_jobs:ticket:'.$ticket->id);
// image -> video uploads start frame (public URL) only then
fresh(['generativelanguage.googleapis.com/*' => Http::response(['candidates'=>[['content'=>['parts'=>[['text'=>'p']]]]]]), 'gen.pollinations.ai/image/models' => Http::response($catalogue),
       'media.pollinations.ai/upload' => Http::response(['id'=>'abc','url'=>'https://media.pollinations.ai/abc','contentType'=>'image/png','size'=>70]),
       'gen.pollinations.ai/video/*' => function ($rq) use (&$i2v) { $i2v = $rq->url(); throw new ConnectionException('cURL error 28: Operation timed out'); }]);
$vs->start($ticket, 7, 'حرك الصورة', App\Models\AiUsageLog::create([]), ['path'=>$tmp,'mime_type'=>'image/png']);
parse_str(parse_url($i2v, PHP_URL_QUERY), $qq);
check('image->video: start frame uploaded and passed as image=', ($qq['image']??'')==='https://media.pollinations.ai/abc');
Cache::forget('ai_video_jobs:ticket:'.$ticket->id);

// ── 8. agent flow: permission -> rate limit -> credits -> record -> generate ─
class FakeCredits extends App\Services\AiCreditService { public bool $allowed = true; public array $reserved = [];
  public function walletForRequest($r) { return (object) []; } public function featureEnabled($w, $f) { return $this->allowed; }
  public function payload($w) { return ['credits'=>100]; }
  public function reserve($request, string $operation, int $credits, ?int $supportTicketId = null, array $metadata = []) { $this->reserved[] = $operation; $u = App\Models\AiUsageLog::create([]); return $u; }
  public function complete(App\Models\AiUsageLog $u, string $p, ?string $m, int $i, int $o) { $this->calls[] = "complete:$p"; $u->credits_used = 40; return $u; } }
class FakeSettings extends App\Services\AssistantSettingsService { public function pluginEnabled($u, $p) { return true; } }
$agent = (new ReflectionClass(App\Services\AiAgent\AiAgentService::class))->newInstanceWithoutConstructor();
$fc = new FakeCredits;
(function ($fc) { $this->credits = $fc; $this->settings = new FakeSettings; $this->gemini = app(App\Services\GeminiSupportService::class);
  $this->imageManager = app(App\Services\AiAgent\ImageGenerationManager::class); $this->videos = app(App\Services\AiAgent\VideoGenerationService::class);
  $this->generations = app(App\Services\AiAgent\AiGenerationRecorder::class); })->call($agent, $fc);
$user = new App\Models\User; $user->id = 7;
$request = Illuminate\Http\Request::create('/x','POST'); $request->setUserResolver(fn() => $user);
$intent = ['tool'=>'image','save_to_project'=>false,'request'=>'صورة داخلية لصالة','source'=>'generation_mode'];
$fc->allowed = false; fresh([]);
$res = $agent->execute($request, $ticket, 'صورة داخلية لصالة', intent: $intent);
check('unauthorized user: 403, no credits reserved, no provider call', ($res['error_status']??0)===403 && $fc->reserved===[] && count(Http::recorded())===0);
$fc->allowed = true;
fresh(['generativelanguage.googleapis.com/*' => Http::response([],500), 'gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::response($imageJson)]);
RateLimiter::clear('ai-media:image:7');
$res = $agent->execute($request, $ticket, 'صورة داخلية لصالة', intent: $intent);
$g = AiGeneration::query()->latest('id')->first();
check('agent image ok: credits reserved then completed', ($res['handled']??false) && !isset($res['error']) && $fc->reserved===['agent_image'] && in_array('complete:image-pollinations', $fc->calls));
check('DB record: completed, interior, text_to_image, provider/model/prompt/user/project', $g->status==='completed' && $g->kind==='interior' && $g->type==='text_to_image' && $g->provider==='pollinations' && $g->model==='tongyi-mai/z-image-turbo' && $g->user_id===7 && $g->project_id===55 && $g->prompt==='صورة داخلية لصالة' && Storage::disk('local')->exists($g->output_path));
check('fallback reason kept in safe metadata', isset($g->metadata['fallbacks']['gemini']));
check('response exposes status only (no key/provider secrets)', ($res['generation']['status']??'')==='completed' && !str_contains(json_encode($res['generation']), $KEY));
fresh(['generativelanguage.googleapis.com/*' => Http::response([],500), 'gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::response(['error'=>['code'=>'PAYMENT_REQUIRED']],402)]);
$fc->calls = [];
$res = $agent->execute($request, $ticket, 'صورة واجهة', intent: $intent);
$g = AiGeneration::query()->latest('id')->first();
check('provider failure -> failed record, refund, retryable response', ($res['generation']['status']??'')==='failed' && $res['generation']['retryable']===true && $g->status==='failed' && $g->error_message && in_array('refund:agent_tool_failed', $fc->calls));
config(['ai_media.rate_limits.images_per_hour'=>2]); RateLimiter::clear('ai-media:image:7');
fresh(['generativelanguage.googleapis.com/*' => Http::response([],500), 'gen.pollinations.ai/image/models' => Http::response($catalogue), 'gen.pollinations.ai/v1/images/generations' => Http::response($imageJson)]);
$agent->execute($request, $ticket, 'a', intent: $intent); $agent->execute($request, $ticket, 'b', intent: $intent); $fc->reserved = [];
$res = $agent->execute($request, $ticket, 'c', intent: $intent);
check('per-user hourly rate limit -> 429 before any credit is reserved', ($res['error_status']??0)===429 && ($res['code']??'')==='ai_media_rate_limited' && $fc->reserved===[]);

// ── 9. capabilities for the UI ──────────────────────────────────────────────
config(['services.gemini.api_key'=>'', 'ai_media.image_providers'=>['pollinations'], 'ai_media.video.providers'=>['pollinations']]);
fresh(['gen.pollinations.ai/image/models' => Http::response($catalogue)]);
$caps = app(App\Services\AiProviders\AiProviderRegistry::class)->mediaCapabilities();
check('capabilities from verified catalogue (booleans only)', $caps===['image'=>true,'edit_image'=>true,'video'=>true]);
fresh(['gen.pollinations.ai/image/models' => Http::response([$catalogue[0]])]);
$caps = app(App\Services\AiProviders\AiProviderRegistry::class)->mediaCapabilities();
check('no verified video/edit model -> buttons hidden', $caps===['image'=>true,'edit_image'=>false,'video'=>false]);
check('recorder scrubs keys from stored reasons', (function() use ($rec, $KEY) { $x = $rec->start(['user_id'=>1,'type'=>'text_to_image','prompt'=>'p']); $rec->fail($x, 'boom '.$KEY.' Bearer abc'); return !str_contains($x->fresh()->error_message, $KEY); })());

echo "\n$ok passed, $fail failed\n";
