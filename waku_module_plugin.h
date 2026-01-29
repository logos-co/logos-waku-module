#pragma once

#include <QtCore/QObject>
#include "waku_module_interface.h"
#include "logos_api.h"
#include "logos_api_client.h"
#include "libwaku.h"

class WakuModulePlugin : public QObject, public WakuModuleInterface
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID WakuModuleInterface_iid FILE "metadata.json")
    Q_INTERFACES(WakuModuleInterface PluginInterface)

public:
    WakuModulePlugin();
    ~WakuModulePlugin();

    Q_INVOKABLE bool foo(const QString &bar) override;
    Q_INVOKABLE bool initWaku(const QString &cfg) override;
    Q_INVOKABLE bool startWaku() override;
    Q_INVOKABLE bool stopWaku() override;
    Q_INVOKABLE bool setEventCallback() override;
    Q_INVOKABLE bool relaySubscribe(const QString &pubSubTopic) override;
    Q_INVOKABLE bool relayPublish(const QString &pubSubTopic, const QString &jsonWakuMessage) override;
    Q_INVOKABLE bool filterSubscribe(const QString &pubSubTopic, const QString &contentTopics) override;
    Q_INVOKABLE bool storeQuery(const QString &jsonQuery, const QString &peerAddr) override;
    Q_INVOKABLE bool getConnectedPeers() override;
    Q_INVOKABLE bool getMetrics() override;
    QString name() const override { return "waku_module"; }
    QString version() const override { return "1.0.0"; }

    // LogosAPI initialization
    Q_INVOKABLE void initLogos(LogosAPI* logosAPIInstance);

signals:
    // for now this is required for events, later it might not be necessary if using a proxy
    void eventResponse(const QString& eventName, const QVariantList& data);

private:
    void* wakuCtx;
    
    // Helper method for emitting events
    void emitEvent(const QString& eventName, const QVariantList& data);
    
    // Static callback functions for waku
    static void init_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void start_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void stop_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void event_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void relay_subscribe_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void relay_publish_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void filter_subscribe_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void store_query_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void get_connected_peers_callback(int callerRet, const char* msg, size_t len, void* userData);
    static void get_metrics_callback(int callerRet, const char* msg, size_t len, void* userData);
}; 