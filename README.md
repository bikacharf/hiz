# Hız Ölçer

Hız Ölçer, iOS ve Android için planlanan bir hız tahmini fizibilite projesidir.
M0 yalnızca koyu/nane uygulama kabuğunu ve mimari sözleşmeleri içerir.
Kamera, algılama, takip ve hız ölçümü henüz çalışmaz; sayısal hız gösterilmez.

Kurulum, sürüm pinleri ve platform doğrulaması: [Geliştirme](docs/DEVELOPMENT.md).

## Başlangıç belgeleri

- [Ürün kapsamı](docs/SPEC.md)
- [Teknik mimari](docs/ARCHITECTURE.md)
- [Aşamalar ve kabul ölçütleri](docs/MILESTONES.md)
- [Cloud çalışma kuralları](docs/RUNBOOK.md)
- [Güncel durum](docs/STATUS.md)
- [İlk Cloud görevi](docs/CLOUD_TASK_01.md)

## Temel ilkeler

- Kamera görüntüsü varsayılan olarak cihaz üzerinde işlenir.
- Ölçüm kalitesi yetersizse hız gösterilmez.
- İnsan, bisiklet, araç ve top için ayrı doğrulama yapılır.
- iOS çalışması Mac ve gerçek iPhone üzerinde doğrulanmadan tamamlanmış sayılmaz.
- Ticari uygulamayla uyumsuz lisanslı kod veya model eklenmez.

