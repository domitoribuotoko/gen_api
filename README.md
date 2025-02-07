Генерация слоя data проекта


Запуск  "dart run gen_yaml gen"
параметры:
    -i Файл документации апи .yaml на вход (По умолчанию openapi.yaml)
    -o место создания папки data (оп умолчанию lib)
    -b Флаг без указания параметра. При наличии генератор вызывает build_runner build в конце

Опции:
    gen_yaml:
        isRunBuilder: true
    Параметр pubspec.yaml. При наличии генератор вызывает build_runner build в конце.
Если параметр явно указан true|false, то наличие/отсутствие флага -b не важно
