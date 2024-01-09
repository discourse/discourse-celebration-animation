import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";

export default class animationEvent extends Service {
  @tracked startAnimation = false;
  currentTime = new Date().getTime();

  storageExpired(objectName) {
    const data = JSON.parse(localStorage.getItem(objectName));
    if (!data) {
      return true;
    }
    return this.currentTime > data.expiresAt;
  }

  setLocalStorage(objectName) {
    const expiryTime = 24 * 60 * 60 * 1000; // 24 hours
    const data = {
      timestamp: this.currentTime,
      expiresAt: this.currentTime + expiryTime,
    };
    localStorage.setItem(objectName, JSON.stringify(data));
  }

  @action
  handleActionToggled() {
    const canvas = document.getElementById("celebration-animation-canvas");
    if (!canvas) {
      // don't trigger if already animating
      this.startAnimation = true;
    }
  }
}
