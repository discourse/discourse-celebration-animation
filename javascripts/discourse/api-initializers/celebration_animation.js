import { apiInitializer } from "discourse/lib/api";
import CelebrationAnimation from "../components/celebration-animation";

export default apiInitializer("1.13.0", (api) => {
  api.renderInOutlet("above-site-header", CelebrationAnimation);

  const animationEventHandler = api.container.lookup("service:animation-event");

  if (settings.display_mode === "first like or solution") {
    api.onAppEvent("page:like-toggled", (post, likeAction) => {
      // trigger on like, not removing a like
      if (likeAction.can_undo) {
        animationEventHandler.handleActionToggled();
      }
    });

    api.onAppEvent("page:solution-toggled", (post) => {
      // trigger on solution, not removing a solution
      if (post.topic_accepted_answer) {
        animationEventHandler.handleActionToggled();
      }
    });
  }
});
