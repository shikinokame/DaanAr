<?php

namespace App\Http\Controllers;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use League\Flysystem\FilesystemException;
use Livewire\Features\SupportFileUploads\FileUploadConfiguration;
use Livewire\Features\SupportFileUploads\FileUploadController;
use Livewire\Features\SupportFileUploads\TemporaryUploadedFile;

class LivewireUploadController extends FileUploadController
{
    public function validateAndStore($files, $disk)
    {
        foreach ((array) $files as $index => $file) {
            if ($file instanceof UploadedFile &&
                strlen(TemporaryUploadedFile::generateHashNameWithOriginalNameEmbedded($file)) > 255) {
                throw ValidationException::withMessages([
                    "files.$index" => 'The filename is too long. Rename the file to a shorter name and upload it again.',
                ]);
            }
        }

        try {
            $paths = parent::validateAndStore($files, $disk);
            $storage = Storage::disk($disk);

            foreach ($paths as $index => $reference) {
                $path = TemporaryUploadedFile::extractPathFromSignedPath($reference);

                if ($path === false || $path === '' || ! $storage->fileExists(FileUploadConfiguration::path($path, false))) {
                    throw ValidationException::withMessages([
                        "files.$index" => 'The server could not save the temporary upload. Please upload the file again.',
                    ]);
                }
            }

            return $paths;
        } catch (FilesystemException $exception) {
            report($exception);

            throw ValidationException::withMessages([
                'files.0' => 'The server could not save the temporary upload. Please try uploading the file again.',
            ]);
        }
    }
}
