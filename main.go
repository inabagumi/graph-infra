package main // github.com/ykzts/aaa

import (
	"log"
	"os"
	"strconv"
	"time"

	"github.com/ChimeraCoder/anaconda"
	influxdb "github.com/influxdata/influxdb1-client/v2"
)

func main() {
	conf := influxdb.HTTPConfig{
		Addr: "http://localhost:8086",
	}
	c, err := influxdb.NewHTTPClient(conf)
	if err != nil {
		log.Fatal(err)
	}
	defer c.Close()

	bp, err := influxdb.NewBatchPoints(influxdb.BatchPointsConfig{
		Database:  "twitter",
		Precision: "s",
	})
	if err != nil {
		log.Fatal(err)
	}

	api := anaconda.NewTwitterApiWithCredentials(
		os.Getenv("TWITTER_ACCESS_TOKEN"),
		os.Getenv("TWITTER_ACCESS_TOKEN_SECRET"),
		os.Getenv("TWITTER_CONSUMER_KEY"),
		os.Getenv("TWITTER_CONSUMER_SECRET"),
	)

	for _, n := range []string{"Haneru_Inaba", "Hinako_Umori", "Ichika_Souya", "Ran_Hinokuma"} {
		user, err := api.GetUsersShow(n, nil)
		if err != nil {
			log.Fatal(err)
		}

		tags := map[string]string{
			"id":          user.IdStr,
			"screen_name": user.ScreenName,
		}

		fields := map[string]interface{}{
			"favourites": user.FavouritesCount,
			"followers":  user.FollowersCount,
			"friends":    user.FriendsCount,
			"statuses":   user.StatusesCount,
		}

		pt, err := influxdb.NewPoint("account", tags, fields, time.Now())
		if err != nil {
			log.Fatal(err)
		}

		bp.AddPoint(pt)

		if user.ScreenName == "Haneru_Inaba" {
			lists, err := api.GetListsOwnedBy(user.Id, nil)
			if err != nil {
				log.Fatal(err)
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

				bp.AddPoint(pt)
			}
		}
	}

	log.Fatal(c.Write(bp))
}
