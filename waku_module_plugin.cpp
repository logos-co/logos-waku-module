#include "waku_module_plugin.h"
#include <QDebug>
#include <QCoreApplication>
#include <QVariantList>
#include <QDateTime>

WakuModulePlugin::WakuModulePlugin() : wakuCtx(nullptr)
{
    qDebug() << "WakuModulePlugin: Initializing...";
    qDebug() << "WakuModulePlugin: Initialized successfully";
}

WakuModulePlugin::~WakuModulePlugin()
{
    // Clean up resources
    if (logosAPI)
    {
        delete logosAPI;
        logosAPI = nullptr;
    }

    // Clean up Waku context if it exists
    if (wakuCtx)
    {
        // TODO: Call waku_destroy when needed
        wakuCtx = nullptr;
    }
}

void WakuModulePlugin::emitEvent(const QString &eventName, const QVariantList &data)
{
    if (!logosAPI)
    {
        qWarning() << "WakuModulePlugin: LogosAPI not available, cannot emit" << eventName;
        return;
    }

    LogosAPIClient *client = logosAPI->getClient("waku_module");
    if (!client)
    {
        qWarning() << "WakuModulePlugin: Failed to get waku_module client for event" << eventName;
        return;
    }

    client->onEventResponse(this, eventName, data);
}

bool WakuModulePlugin::foo(const QString &bar)
{
    qDebug() << "WakuModulePlugin::foo called with:" << bar;

    // Create event data with the bar parameter
    QVariantList eventData;
    eventData << bar;                                                // Add the bar parameter to the event data
    eventData << QDateTime::currentDateTime().toString(Qt::ISODate); // Add timestamp

    // Trigger the event using emitEvent helper
    qDebug() << "WakuModulePlugin: Triggering event 'fooTriggered' with data:" << eventData;
    emitEvent("fooTriggered", eventData);
    qDebug() << "WakuModulePlugin: Event 'fooTriggered' triggered with data:" << eventData;

    return true;
}

void WakuModulePlugin::init_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::init_callback called with ret:" << callerRet;
    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::init_callback message:" << message;
    }

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (plugin)
    {
        plugin->m_initSuccess.store(callerRet == RET_OK);
        plugin->m_initSemaphore.release();
    }
}

void WakuModulePlugin::start_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::start_callback called with ret:" << callerRet;
    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::start_callback message:" << message;
    }

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (plugin)
    {
        plugin->m_startSuccess.store(callerRet == RET_OK);
        plugin->m_startSemaphore.release();
    }
}

void WakuModulePlugin::event_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::event_callback called with ret:" << callerRet;

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (!plugin)
    {
        qWarning() << "WakuModulePlugin::event_callback: Invalid userData";
        return;
    }

    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        // qDebug() << "WakuModulePlugin::event_callback message:" << message;

        // Create event data with the message
        QVariantList eventData;
        eventData << message;
        eventData << QDateTime::currentDateTime().toString(Qt::ISODate);

        // Trigger event using emitEvent helper
        // qDebug() << "------------------------> WakuModulePlugin: Triggering event 'wakuMessage' with data:" << eventData;
        plugin->emitEvent("wakuMessage", eventData);
    }
}

void WakuModulePlugin::relay_subscribe_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::relay_subscribe_callback called with ret:" << callerRet;
    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::relay_subscribe_callback message:" << message;
    }
}

void WakuModulePlugin::relay_publish_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::relay_publish_callback called with ret:" << callerRet;
    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::relay_publish_callback message:" << message;
    }
}

void WakuModulePlugin::light_publish_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::light_publish_callback called with ret:" << callerRet;
    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        if (callerRet == RET_OK)
        {
            qDebug() << "WakuModulePlugin::light_publish_callback msgHash:" << message;
        }
        else
        {
            qWarning() << "WakuModulePlugin::light_publish_callback error:" << message;
        }
    }
}

void WakuModulePlugin::filter_subscribe_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::filter_subscribe_callback called with ret:" << callerRet;
    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::filter_subscribe_callback message:" << message;
    }
}

void WakuModulePlugin::store_query_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::store_query_callback called with ret:" << callerRet;

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (!plugin)
    {
        qWarning() << "WakuModulePlugin::store_query_callback: Invalid userData";
        exit(1);
        return;
    }

    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        // qDebug() << "WakuModulePlugin::store_query_callback message:" << message;

        // Create event data with the store query result
        QVariantList eventData;
        eventData << message;
        eventData << QDateTime::currentDateTime().toString(Qt::ISODate);

        // Trigger event using emitEvent helper
        // qDebug() << "WakuModulePlugin: Triggering event 'storeQueryResponse' with data:" << eventData;
        plugin->emitEvent("storeQueryResponse", eventData);
    }
}

void WakuModulePlugin::stop_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::stop_callback called with ret:" << callerRet;
    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::stop_callback message:" << message;
    }
}

void WakuModulePlugin::get_connected_peers_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::get_connected_peers_callback called with ret:" << callerRet;

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (!plugin)
    {
        qWarning() << "WakuModulePlugin::get_connected_peers_callback: Invalid userData";
        return;
    }

    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::get_connected_peers_callback message:" << message;
        qDebug() << "WakuModulePlugin::get_connected_peers_callback message length:" << len;

        // Create event data with the connected peers result
        QVariantList eventData;
        eventData << message;
        eventData << QDateTime::currentDateTime().toString(Qt::ISODate);

        // Trigger event using emitEvent helper
        qDebug() << "WakuModulePlugin: Triggering event 'connectedPeersResponse' with data:" << eventData;
        plugin->emitEvent("connectedPeersResponse", eventData);
    }
}

void WakuModulePlugin::get_metrics_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::get_metrics_callback called with ret:" << callerRet;

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (!plugin)
    {
        qWarning() << "WakuModulePlugin::get_metrics_callback: Invalid userData";
        return;
    }

    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::get_metrics_callback message:" << message;
        qDebug() << "WakuModulePlugin::get_metrics_callback message length:" << len;

        // Create event data with the metrics result
        QVariantList eventData;
        eventData << message;
        eventData << QDateTime::currentDateTime().toString(Qt::ISODate);

        // Trigger event using emitEvent helper
        qDebug() << "WakuModulePlugin: Triggering event 'metricsResponse' with data:" << eventData;
        plugin->emitEvent("metricsResponse", eventData);
    }
}

void WakuModulePlugin::initLogos(LogosAPI *logosAPIInstance)
{
    if (logosAPI)
    {
        delete logosAPI;
    }
    logosAPI = logosAPIInstance;
}

bool WakuModulePlugin::initWaku(const QString &cfg)
{
    qDebug() << "WakuModulePlugin-Updated::initWaku called with cfg:" << cfg;

    // Convert QString to UTF-8 byte array
    QByteArray cfgUtf8 = cfg.toUtf8();

    // Call waku_new with the configuration
    wakuCtx = waku_new(cfgUtf8.constData(), init_callback, this);

    if (wakuCtx)
    {
        qDebug() << "WakuModulePlugin: Waku context created successfully";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to create Waku context";
        return false;
    }
}

bool WakuModulePlugin::startWaku()
{
    qDebug() << "WakuModulePlugin::startWaku called";

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot start Waku - context not initialized. Call initWaku first.";
        return false;
    }

    // Wait for init_callback to signal that waku_new has fully completed
    qDebug() << "WakuModulePlugin: Waiting for node initialization to complete...";
    if (!m_initSemaphore.tryAcquire(1, 30000))
    {
        qWarning() << "WakuModulePlugin: Timed out waiting for Waku node initialization (30s)";
        return false;
    }

    if (!m_initSuccess.load())
    {
        qWarning() << "WakuModulePlugin: Waku node initialization failed, cannot start";
        return false;
    }

    qDebug() << "WakuModulePlugin: Node initialization confirmed, starting Waku...";

    // Call waku_start with the saved context
    int result = waku_start(wakuCtx, start_callback, this);

    if (result == RET_OK)
    {
        qDebug() << "==================WakuModulePlugin: Waku start initiated successfully=======================";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to start Waku, error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::setEventCallback()
{
    qDebug() << "WakuModulePlugin::setEventCallback called";

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot set event callback - context not initialized. Call initWaku first.";
        return false;
    }

    // Set the event callback using waku_set_event_callback
    set_event_callback(wakuCtx, event_callback, this);

    qDebug() << "WakuModulePlugin: Event callback set successfully";
    return true;
}

bool WakuModulePlugin::relaySubscribe(const QString &contentTopic, const QString &pubSubTopic)
{
    qDebug() << "WakuModulePlugin::relaySubscribe called with contentTopic:" << contentTopic << ", pubSubTopic:" << pubSubTopic;

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot subscribe to relay - context not initialized. Call initWaku first.";
        return false;
    }

    // Convert QStrings to UTF-8 byte arrays
    QByteArray contentTopicUtf8 = contentTopic.toUtf8();
    QByteArray pubSubTopicUtf8 = pubSubTopic.toUtf8();

    // Call waku_relay_subscribe with both pubSubTopic and contentTopic
    // Pass empty string "" if not provided instead of nullptr
    int result = waku_relay_subscribe(wakuCtx, relay_subscribe_callback, this,
                                      pubSubTopicUtf8.isEmpty() ? "" : pubSubTopicUtf8.constData(),
                                      contentTopicUtf8.isEmpty() ? "" : contentTopicUtf8.constData());

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Relay subscribe initiated successfully";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to subscribe to relay, error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::relayPublish(const QString &pubSubTopic, const QString &jsonWakuMessage)
{
    qDebug() << "WakuModulePlugin::relayPublish called with pubSubTopic:" << pubSubTopic;
    qDebug() << "WakuModulePlugin::relayPublish message:" << jsonWakuMessage;

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot publish to relay - context not initialized. Call initWaku first.";
        return false;
    }

    // Convert QStrings to UTF-8 byte arrays
    QByteArray topicUtf8 = pubSubTopic.toUtf8();
    QByteArray messageUtf8 = jsonWakuMessage.toUtf8();

    // Call waku_relay_publish with hardcoded timeout of 10000ms
    int result = waku_relay_publish(wakuCtx, relay_publish_callback, this, topicUtf8.constData(), messageUtf8.constData(), 10000);

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Relay publish initiated successfully for topic:" << pubSubTopic;
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to publish to relay topic:" << pubSubTopic << ", error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::lightPublish(const QString &pubSubTopic, const QString &jsonWakuMessage)
{
    qDebug() << "WakuModulePlugin::lightPublish called with pubSubTopic:" << pubSubTopic;
    qDebug() << "WakuModulePlugin::lightPublish message:" << jsonWakuMessage;

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot publish using lightpush - context not initialized. Call initWaku first.";
        return false;
    }

    // Convert QStrings to UTF-8 byte arrays
    QByteArray topicUtf8 = pubSubTopic.toUtf8();
    QByteArray messageUtf8 = jsonWakuMessage.toUtf8();

    // why there is no timeout for lightpush publish???
    int result = waku_lightpush_publish(wakuCtx, light_publish_callback, this, topicUtf8.constData(), messageUtf8.constData());

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Lightpush publish initiated successfully for topic:" << pubSubTopic;
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to publish to lightpush topic:" << pubSubTopic << ", error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::filterSubscribe(const QString &pubSubTopic, const QString &contentTopics)
{
    qDebug() << "WakuModulePlugin::filterSubscribe called with pubSubTopic:" << pubSubTopic;
    qDebug() << "WakuModulePlugin::filterSubscribe contentTopics:" << contentTopics;

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot subscribe to filter - context not initialized. Call initWaku first.";
        return false;
    }

    // Convert QStrings to UTF-8 byte arrays
    QByteArray topicUtf8 = pubSubTopic.toUtf8();
    QByteArray contentTopicsUtf8 = contentTopics.toUtf8();

    // Call waku_filter_subscribe
    int result = waku_filter_subscribe(wakuCtx, filter_subscribe_callback, this, topicUtf8.constData(), contentTopicsUtf8.constData());

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Filter subscribe initiated successfully for topic:" << pubSubTopic;
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to subscribe to filter topic:" << pubSubTopic << ", error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::storeQuery(const QString &jsonQuery, const QString &peerAddr)
{
    qDebug() << "WakuModulePlugin::storeQuery called with jsonQuery:" << jsonQuery;
    qDebug() << "WakuModulePlugin::storeQuery peerAddr:" << peerAddr;

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot execute store query - context not initialized. Call initWaku first.";
        return false;
    }

    // Convert QStrings to UTF-8 byte arrays
    QByteArray queryUtf8 = jsonQuery.toUtf8();
    QByteArray peerAddrUtf8 = peerAddr.toUtf8();

    // Call waku_store_query with hardcoded timeout of 30000ms
    int result = waku_store_query(wakuCtx, store_query_callback, this, queryUtf8.constData(), peerAddrUtf8.constData(), 30000);

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Store query initiated successfully for peer:" << peerAddr;
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to execute store query for peer:" << peerAddr << ", error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::stopWaku()
{
    qDebug() << "WakuModulePlugin::stopWaku called";

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot stop Waku - context not initialized. Call initWaku first.";
        return false;
    }

    // Call waku_stop with the saved context
    int result = waku_stop(wakuCtx, stop_callback, this);

    if (result == RET_OK)
    {
        qDebug() << "==================WakuModulePlugin: Waku stop initiated successfully=======================";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to stop Waku, error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::getConnectedPeers()
{
    qDebug() << "WakuModulePlugin::getConnectedPeers called";

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot get connected peers - context not initialized. Call initWaku first.";
        return false;
    }

    // Call waku_get_connected_peers
    int result = waku_get_connected_peers(wakuCtx, get_connected_peers_callback, this);

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Get connected peers initiated successfully";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to get connected peers, error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::getMetrics()
{
    qDebug() << "WakuModulePlugin::getMetrics called";

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot get metrics - context not initialized. Call initWaku first.";
        return false;
    }

    // Call waku_get_metrics
    int result = waku_get_metrics(wakuCtx, get_metrics_callback, this);

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Get metrics initiated successfully";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to get metrics, error code:" << result;
        return false;
    }
}

void WakuModulePlugin::get_mixnode_pool_size_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::get_mixnode_pool_size_callback called with ret:" << callerRet;

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (!plugin)
    {
        qWarning() << "WakuModulePlugin::get_mixnode_pool_size_callback: Invalid userData";
        return;
    }

    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::get_mixnode_pool_size_callback message:" << message;

        // Create event data with the mixnode pool size result
        QVariantList eventData;
        eventData << message;
        eventData << QDateTime::currentDateTime().toString(Qt::ISODate);

        // Trigger event using emitEvent helper
        plugin->emitEvent("mixnodePoolSizeResponse", eventData);
    }
}

void WakuModulePlugin::get_lightpush_peers_count_callback(int callerRet, const char *msg, size_t len, void *userData)
{
    qDebug() << "WakuModulePlugin::get_lightpush_peers_count_callback called with ret:" << callerRet;

    WakuModulePlugin *plugin = static_cast<WakuModulePlugin *>(userData);
    if (!plugin)
    {
        qWarning() << "WakuModulePlugin::get_lightpush_peers_count_callback: Invalid userData";
        return;
    }

    if (msg && len > 0)
    {
        QString message = QString::fromUtf8(msg, len);
        qDebug() << "WakuModulePlugin::get_lightpush_peers_count_callback message:" << message;

        // Create event data with the lightpush peers count result
        QVariantList eventData;
        eventData << message;
        eventData << QDateTime::currentDateTime().toString(Qt::ISODate);

        // Trigger event using emitEvent helper
        plugin->emitEvent("lightpushPeersCountResponse", eventData);
    }
}

bool WakuModulePlugin::getMixnodePoolSize()
{
    qDebug() << "WakuModulePlugin::getMixnodePoolSize called";

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot get mixnode pool size - context not initialized. Call initWaku first.";
        return false;
    }

    // Call waku_get_mixnode_pool_size
    int result = waku_get_mixnode_pool_size(wakuCtx, get_mixnode_pool_size_callback, this);

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Get mixnode pool size initiated successfully";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to get mixnode pool size, error code:" << result;
        return false;
    }
}

bool WakuModulePlugin::getLightpushPeersCount()
{
    qDebug() << "WakuModulePlugin::getLightpushPeersCount called";

    if (!wakuCtx)
    {
        qWarning() << "WakuModulePlugin: Cannot get lightpush peers count - context not initialized. Call initWaku first.";
        return false;
    }

    // Call waku_get_lightpush_peers_count
    int result = waku_get_lightpush_peers_count(wakuCtx, get_lightpush_peers_count_callback, this);

    if (result == RET_OK)
    {
        qDebug() << "WakuModulePlugin: Get lightpush peers count initiated successfully";
        return true;
    }
    else
    {
        qWarning() << "WakuModulePlugin: Failed to get lightpush peers count, error code:" << result;
        return false;
    }
}
