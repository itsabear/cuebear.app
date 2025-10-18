#include <stdio.h>
#include <unistd.h>
#include <usbmuxd.h>

void device_callback(const usbmuxd_event_t *event, void *user_data) {
    switch (event->event) {
        case UE_DEVICE_ADD:
            printf("✅ Device attached: %s\n", event->device.udid);
            break;
        case UE_DEVICE_REMOVE:
            printf("✅ Device detached: %s\n", event->device.udid);
            break;
        case UE_DEVICE_PAIRED:
            printf("✅ Device paired: %s\n", event->device.udid);
            break;
    }
}

int main() {
    printf("Testing libusbmuxd...\n");

    // Test 1: Get device list
    usbmuxd_device_info_t *device_list = NULL;
    int count = usbmuxd_get_device_list(&device_list);

    if (count < 0) {
        printf("❌ Error getting device list: %d\n", count);
        return 1;
    }

    printf("✅ Device count: %d\n", count);

    if (count > 0 && device_list) {
        for (int i = 0; i < count; i++) {
            printf("  Device %d: UDID=%s, handle=%u\n",
                   i, device_list[i].udid, device_list[i].handle);
        }
        usbmuxd_device_list_free(&device_list);
    }

    // Test 2: Subscribe to events
    printf("\nSubscribing to device events for 5 seconds...\n");
    usbmuxd_subscription_context_t context = NULL;
    int result = usbmuxd_events_subscribe(&context, device_callback, NULL);

    if (result != 0) {
        printf("❌ Failed to subscribe to events: %d\n", result);
        return 1;
    }

    printf("✅ Successfully subscribed to events\n");
    printf("Waiting for events (plug/unplug device now)...\n");

    sleep(5);

    usbmuxd_events_unsubscribe(context);
    printf("✅ Unsubscribed successfully\n");

    return 0;
}
