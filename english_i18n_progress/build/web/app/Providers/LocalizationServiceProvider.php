<?php

namespace App\Providers;

use App\Http\Controllers\UiLocaleController;
use App\Http\Middleware\SetLocale;
use App\Support\Localization\AutoTranslator;
use App\Support\Localization\Dictionary;
use App\View\TranslatingCompilerEngine;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;
use Illuminate\View\Engines\EngineResolver;

/**
 * English interface for the whole platform (Arabic stays the default).
 *
 * Enabled from AppServiceProvider::register() with one line:
 *     $this->app->register(\App\Providers\LocalizationServiceProvider::class);
 *
 * Turn everything off without touching code: UI_I18N_ENABLED=false in .env
 */
class LocalizationServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        if (!$this->enabled()) {
            return;
        }

        // Dictionary is loaded lazily: Arabic pages never pay for it.
        $this->app->singleton(AutoTranslator::class, fn () => new AutoTranslator(fn () => Dictionary::load()));

        try {
            if ($this->app->resolved('view.engine.resolver')) {
                $this->registerBladeEngine($this->app->make('view.engine.resolver'));
            } else {
                $this->app->afterResolving('view.engine.resolver', function ($resolver) {
                    $this->registerBladeEngine($resolver);
                });
            }
        } catch (\Throwable $e) {
            report($e);
        }
    }

    public function boot(): void
    {
        if (!$this->enabled()) {
            return;
        }

        // Read the language cookie as plain text (it only holds "ar" or "en").
        try {
            if (method_exists(EncryptCookies::class, 'except')) {
                EncryptCookies::except(['ui_locale']);
            }
        } catch (\Throwable $e) {
            report($e);
        }

        try {
            $router = $this->app['router'];
            $router->pushMiddlewareToGroup('web', SetLocale::class);
            $router->pushMiddlewareToGroup('api', SetLocale::class);

            // Also globally, so 404 pages and requests outside the groups follow the choice.
            $kernel = $this->app->make(HttpKernel::class);
            if (method_exists($kernel, 'hasMiddleware') && method_exists($kernel, 'pushMiddleware') && !$kernel->hasMiddleware(SetLocale::class)) {
                $kernel->pushMiddleware(SetLocale::class);
            }
        } catch (\Throwable $e) {
            report($e);
        }

        try {
            if (!$this->app->routesAreCached()) {
                $this->registerRoutes();
            }
        } catch (\Throwable $e) {
            report($e);
        }
    }

    private function registerRoutes(): void
    {
        Route::middleware('web')
            ->get('/lang/{locale}', [UiLocaleController::class, 'switch'])
            ->where('locale', 'ar|en')
            ->name('ui-locale.switch');

        Route::post('/lang/translate', [UiLocaleController::class, 'translate'])
            ->middleware(ThrottleRequests::class . ':120,1')
            ->name('ui-locale.translate');
    }

    private function registerBladeEngine(EngineResolver $resolver): void
    {
        $app = $this->app;
        $resolver->register('blade', function () use ($app) {
            $engine = new TranslatingCompilerEngine($app->make('blade.compiler'), $app->make('files'));
            if (method_exists($engine, 'forgetCompiledOrNotExpired')) {
                $app->terminating(static function () use ($engine) {
                    $engine->forgetCompiledOrNotExpired();
                });
            }

            return $engine;
        });
    }

    private function enabled(): bool
    {
        $flag = env('UI_I18N_ENABLED', true);

        return !in_array($flag, [false, 0, '0', 'false', 'off', 'no'], true);
    }
}
