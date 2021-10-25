#!/usr/bin/env runclj
^{:runclj {:browser-mode true
           :lein [[org.clojure/clojure "1.10.3"]
                  [org.clojure/core.async "1.3.618"]
                  [org.clojure/clojurescript "1.10.879"]
                  [cljs-http "0.1.46"]
                  [garden "1.3.10"]
                  [arttuka/reagent-material-ui "5.0.0-beta.5-0"]
                  [funcool/bide "1.7.0"]
                  [reagent "1.1.0"]
                  [cljsjs/react "17.0.2-0"]
                  [cljsjs/react-dom "17.0.2-0"]]}}

(ns frontend
  (:require-macros [cljs.core.async.macros :refer [go go-loop]])
  (:require [cljs-http.client :as http]
            [cljs.core.async :refer [<! >! chan timeout]]
            [cljs.pprint]
            [reagent.dom :as reagent.dom]
            [reagent.core :as reagent]
            [bide.core :as bide]
            [garden.core :as garden]
            [clojure.string :as s]
            [clojure.browser.repl :as repl]
            [reagent-material-ui.core.app-bar :refer [app-bar]]
            [reagent-material-ui.core.box :refer [box]]
            [reagent-material-ui.core.breadcrumbs :refer [breadcrumbs]]
            [reagent-material-ui.core.button :refer [button]]
            [reagent-material-ui.core.card :refer [card]]
            [reagent-material-ui.core.text-field :refer [text-field]]
            [reagent-material-ui.core.card-action-area :refer [card-action-area]]
            [reagent-material-ui.core.card-content :refer [card-content]]
            [reagent-material-ui.core.card-media :refer [card-media]]
            [reagent-material-ui.core.container :refer [container]]
            [reagent-material-ui.core.modal :refer [modal]]
            [reagent-material-ui.core.tab :refer [tab]]
            [reagent-material-ui.core.tabs :refer [tabs]]
            [reagent-material-ui.core.divider :refer [divider]]
            [reagent-material-ui.core.drawer :refer [drawer]]
            [reagent-material-ui.core.grid :refer [grid]]
            [reagent-material-ui.core.hidden :refer [hidden]]
            [reagent-material-ui.core.icon-button :refer [icon-button]]
            [reagent-material-ui.core.link :refer [link]]
            [reagent-material-ui.core.list :refer [list]]
            [reagent-material-ui.core.list-item :refer [list-item]]
            [reagent-material-ui.core.list-item-text :refer [list-item-text]]
            [reagent-material-ui.core.toolbar :refer [toolbar]]
            [reagent-material-ui.core.typography :refer [typography]]
            [reagent-material-ui.icons.home :refer [home]]
            [reagent-material-ui.icons.sms :refer [sms]]
            [reagent-material-ui.icons.mail :refer [mail]]
            [reagent-material-ui.icons.folder :refer [folder]]
            [reagent-material-ui.icons.bookmark :refer [bookmark]]))

(defn log [& args] (apply js/console.log (map clj->js args)))

(do

  (set! *warn-on-infer* true)

  (let [id (atom 0)
        -gen-id (memoize
                 (fn [& args]
                   (swap! id inc)))]
    (defn gen-id [& args]
      (apply -gen-id args)))

  (defonce state
    (reagent/atom
     {:page home}))

  (def style
    (garden/css
     [:body {:background-color "rgb(240, 240, 240)"}]
     [:.bg-color {:background-color "rgb(230, 230, 230)"}]
     ["*" {:font-family "monospace !important"}]
     [:.MuiIconButton-root {:border-radius "10%"}]
     [:.MuiAppBar-colorPrimary {:background-color "rgb(230, 230, 230)"}]
     [".menu-button .MuiSvgIcon-root" {:width "40px"
                                       :height "40px"}]))

  (defn component-menu-button [page-name page-component icon]
    [icon-button {:id page-name
                  :class "menu-button"
                  :on-click #(swap! state merge {:page page-component})
                  :style  (merge {:padding "15px"}
                                 (if (= page-component (:page @state))
                                   {:color "red"}))}
     [grid
      [icon]
      [typography {:style {:font-weight 700}} page-name]]])

  (defn component-root []
    [:<>
     [:style style]
     (if (:modal-open @state)
       [component-help]
       [component-main])])

  (defn component-main []
    [:<>
     [app-bar {:position "relative"}
      [toolbar {:style {:padding 0}}
       [component-menu-button "home"  component-home  home]
       [component-menu-button "other" component-other  sms]]]
     [container {:id "content" :style {:padding 0 :margin-top "10px"}}
      [card {:style {:padding "20px"}
             :class "bg-color"}
       [(:page @state)]]]])

  (defn state-fetch []
    (go (let [resp (<! (http/get "http://localhost:8080/value" {:with-credentials? false}))]
          (if (:success resp)
            (swap! state assoc :value (js/Number.parseInt (:body resp))))
          (log :state-fetch resp))))

  (defn state-wipe []
    (go (let [resp (<! (http/get "http://localhost:8080/wipe" {:with-credentials? false}))]
          (log :state-wipe resp))
        (<! (state-fetch)))
    nil)

  (defn component-home []
    [:div
     [:button
      {:on-click state-fetch
       :id "value"}
      "click to increment database value"]
     [:span
      {:style {:margin-left "5px"}
       :id "value"}
      (:value @state)]])

  (defn component-other []
    [:div
     [:span "other page"]])

  (defn component-not-found []
    [:div
     [:p "404"]])

  (def router
    [["/" component-home]
     ["(.*)" component-not-found]])

  (defn href-parts []
    (s/split (last (s/split js/window.location.href #"#/")) #"/"))

  (defn -main []
    ;; (defonce repl (repl/connect "http://10.0.1.5:9000/repl")) ;; phone
    (defonce repl (repl/connect "http://localhost:9000/repl")) ;; localhost
    (defonce init (state-fetch))
    (bide/start! (bide/router router) {:default home
                                       :on-navigate #(swap! state merge {:page % :parts (href-parts)})
                                       :html5? false})
    (reagent.dom/render [component-root] (js/document.getElementById "app")))

  (-main))
