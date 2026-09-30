تكامل Pollinations — منصة الوليد الهندسية
==========================================
1) استبدل الملفات بنفس المسارات.
2) Railway > Variables: أضف POLLINATIONS_API_KEY (مفتاح sk_ السري). POLLINATIONS_BASE_URL اختياري (الافتراضي https://gen.pollinations.ai).
   إذا كان عندك AI_IMAGE_PROVIDERS أو AI_VIDEO_PROVIDERS مضبوطين مسبقًا في Railway، أضف لهم الكلمة pollinations:
     AI_IMAGE_PROVIDERS=gemini,pollinations,cloudflare,huggingface,self_hosted
     AI_VIDEO_PROVIDERS=veo,pollinations,comfyui
     AI_TEXT_PROVIDERS=gemini,pollinations
3) php artisan migrate --force   (ينشئ جدول ai_generations)
4) php artisan config:clear && php artisan view:clear
5) فحص مجاني:            php artisan pollinations:check
   فحص نص (شبه مجاني):    php artisan pollinations:check --text
   صورة واحدة صغيرة:       php artisan pollinations:test-image --user=1
   فيديو (يدوي، مدفوع):   php artisan pollinations:test-video
