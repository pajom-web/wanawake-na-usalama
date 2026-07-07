{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    useLocalCanvasKit: true,
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById("splash")?.remove();
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
