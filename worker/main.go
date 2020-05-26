package main // import "github.com/inabagumi/graph/worker"

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/ChimeraCoder/anaconda"
	influxdb2 "github.com/influxdata/influxdb-client-go"
	"github.com/influxdata/influxdb-client-go/api"
)

type Target struct {
	ID         int64  `json:"id"`
	ScreenName string `json:"screen_name"`
	Group      string `json:"group"`
	Retired    bool   `json:"retired"`
}

var twitterApi *anaconda.TwitterApi
var targets []Target

func init() {
	twitterApi = anaconda.NewTwitterApiWithCredentials(
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

func getTarget(id int64) Target {
	for _, target := range targets {
		if target.ID == id {
			return target
		}
	}

	return Target{}
}

func index(writeApi api.WriteApi, now time.Time) error {
	var ids []int64
	for _, t := range targets {
		ids = append(ids, t.ID)
	}

	users, err := twitterApi.GetUsersLookupByIds(ids, nil)
	if err != nil {
		return err
	}

	for _, user := range users {
		t := getTarget(user.Id)
		retired := "false"

		if t.Retired {
			retired = "true"
		}

		p := influxdb2.NewPointWithMeasurement("account").
			AddTag("group", t.Group).
			AddTag("id", user.IdStr).
			AddTag("screen_name", user.ScreenName).
			AddTag("retired", retired).
			AddField("favourites", user.FavouritesCount).
			AddField("followers", user.FollowersCount).
			AddField("friends", user.FriendsCount).
			AddField("statuses", user.StatusesCount).
			SetTime(now)

		writeApi.WritePoint(p)
	}

	return nil
}

func index2(writeApi api.WriteApi, now time.Time) error {
	lists, err := twitterApi.GetListsOwnedBy(995247053977485313, nil)
	if err != nil {
		return err
	}

	for _, list := range lists {
		id := strconv.FormatInt(list.Id, 10)

		p := influxdb2.NewPointWithMeasurement("list").
			AddTag("id", id).
			AddTag("name", list.Name).
			AddTag("owner", list.User.IdStr).
			AddField("members", list.MemberCount)

		writeApi.WritePoint(p)
	}

	return nil
}

func worker(client influxdb2.Client) {
	writeApi := client.WriteApi("", "twitter")
	defer writeApi.Close()

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	err := index(writeApi, time.Now())
	if err != nil {
		log.Printf("Error: %v", err)
	}

	for t := range ticker.C {
		err = index(writeApi, t)
		if err != nil {
			log.Printf("Error: %v", err)
		}
	}
}

func worker2(client influxdb2.Client) {
	writeApi := client.WriteApi("", "twitter")
	defer writeApi.Close()

	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	err := index2(writeApi, time.Now())
	if err != nil {
		log.Printf("Error: %v", err)
	}

	for t := range ticker.C {
		err = index2(writeApi, t)
		if err != nil {
			log.Printf("Error: %v", err)
		}
	}
}

func main() {
	client := influxdb2.NewClientWithOptions("http://influxdb:8086", "",
		influxdb2.DefaultOptions().SetLogLevel(3).SetPrecision(time.Second))
	defer client.Close()

	go worker(client)
	go worker2(client)

	select {}
}
