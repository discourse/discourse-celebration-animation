import { apiInitializer } from "discourse/lib/api";
import CelebrationAnimation from "../components/celebration-animation";

export default apiInitializer("1.13.0", (api) => {
  api.renderInOutlet("above-site-header", CelebrationAnimation);

  const animationEventHandler = api.container.lookup("service:animation-event");

  if (settings.display_mode === "first like or solution") {
    api.onAppEvent("discourse-reactions:reaction-toggled", (post, reaction) => {
      // trigger on like, not removing a like
      if (reaction) {
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
