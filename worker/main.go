package main // import "github.com/ykzts/graph/worker"

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/ChimeraCoder/anaconda"
	influxdb "github.com/influxdata/influxdb1-client/v2"
)

type Target struct {
	ID         int64  `json:"id"`
	ScreenName string `json:"screen_name"`
	Group      string `json:"group"`
}

var api *anaconda.TwitterApi
var targets []Target

func init() {
	api = anaconda.NewTwitterApiWithCredentials(
		os.Getenv("TWITTER_ACCESS_TOKEN"),
		os.Getenv("TWITTER_ACCESS_TOKEN_SECRET"),
		os.Getenv("TWITTER_CONSUMER_KEY"),
		os.Getenv("TWITTER_CONSUMER_SECRET"),
	)

	file, err := ioutil.ReadFile("/etc/worker/targets.json")
	if err != nil {
		log.Fatal(err)
	}

	err = json.Unmarshal([]byte(file), &targets)
	if err != nil {
		log.Fatal(err)
	}
}

func getGroup(id int64) string {
	for _, target := range targets {
		if target.ID == id {
			return target.Group
		}
	}

	return ""
}

func index(client influxdb.Client, now time.Time) error {
	bp, err := influxdb.NewBatchPoints(influxdb.BatchPointsConfig{
		Database:  "twitter",
		Precision: "s",
	})
	if err != nil {
		return err
	}

	var ids []int64
	for _, t := range targets {
		ids = append(ids, t.ID)
	}

	users, err := api.GetUsersLookupByIds(ids, nil)
	if err != nil {
		return err
	}

	for _, user := range users {
		tags := map[string]string{
			"group":       getGroup(user.Id),
			"id":          user.IdStr,
			"screen_name": user.ScreenName,
		}

		fields := map[string]interface{}{
			"favourites": user.FavouritesCount,
			"followers":  user.FollowersCount,
			"friends":    user.FriendsCount,
			"statuses":   user.StatusesCount,
		}

		pt, err := influxdb.NewPoint("account", tags, fields, now)
		if err != nil {
			return err
		}

		log.Println(pt)
		bp.AddPoint(pt)
	}

	return client.Write(bp)
}

func index2(client influxdb.Client, now time.Time) error {
	bp, err := influxdb.NewBatchPoints(influxdb.BatchPointsConfig{
		Database:  "twitter",
		Precision: "s",
	})
	if err != nil {
		return err
	}

	lists, err := api.GetListsOwnedBy(995247053977485313, nil)
	if err != nil {
		return err
	}

	for _, list := range lists {
		id := strconv.FormatInt(list.Id, 10)

		tags := map[string]string{
			"id":    id,
			"name":  list.Name,
			"owner": list.User.IdStr,
		}

		fields := map[string]interface{}{
			"members": list.MemberCount,
		}

		pt, err := influxdb.NewPoint("list", tags, fields, time.Now())
		if err != nil {
			log.Fatal(err)
		}

		log.Print(pt)
		bp.AddPoint(pt)
	}

	return client.Write(bp)
}

func worker(client influxdb.Client) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	err := index(client, time.Now())
	if err != nil {
		log.Printf("Error: %v", err)
	}

	for t := range ticker.C {
		err = index(client, t)
		if err != nil {
			log.Printf("Error: %v", err)
		}
	}
}

func worker2(client influxdb.Client) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	err := index2(client, time.Now())
	if err != nil {
		log.Printf("Error: %v", err)
	}

	for t := range ticker.C {
		err = index2(client, t)
		if err != nil {
			log.Printf("Error: %v", err)
		}
	}
}

func main() {
	conf := influxdb.HTTPConfig{
		Addr: "http://influxdb:8086",
	}
	client, err := influxdb.NewHTTPClient(conf)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	go worker(client)
	go worker2(client)

	select {}
}
