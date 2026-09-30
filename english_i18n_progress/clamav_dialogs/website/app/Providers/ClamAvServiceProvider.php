<?php

namespace App\Providers;

use App\Http\Middleware\ScanUploadedFiles;
use Illuminate\Routing\Router;
use Illuminate\Support\ServiceProvider;

/** Adds the upload virus scan to the web and api middleware groups. */
class ClamAvServiceProvider extends ServiceProvider
{
    public function boot(Router $router): void
    {
        foreach (['web', 'api'] as $group) {
            $router->pushMiddlewareToGroup($group, ScanUploadedFiles::class);
        }
    }
}
