package main // import "github.com/ykzts/aaa"

import (
	"log"
	"os"
	"strconv"
	"time"

	"github.com/ChimeraCoder/anaconda"
	influxdb "github.com/influxdata/influxdb1-client/v2"
)

var targets = []struct {
	ID         int64
	ScreenName string
	Group      string
}{
	{
		992355895051866112,
		"_kanade_kanon",
		"VApArt",
	},
	{
		993839162099810305,
		"AniMare_cafe",
		"AniMare",
	},
	{
		388327297,
		"camomi_camomi",
		"VApArt",
	},
	{
		1007316805981892613,
		"Charlotte_HNST",
		"HoneyStrap",
	},
	{
		1007290563756871681,
		"Eli_HNST",
		"HoneyStrap",
	},
	{
		995247053977485313,
		"Haneru_Inaba",
		"AniMare",
	},
	{
		1007247110167674881,
		"HNST_official",
		"HoneyStrap",
	},
	{
		995250952373391360,
		"Hinako_Umori",
		"AniMare",
	},
	{
		995253301472972801,
		"Ichika_Souya",
		"AniMare",
	},
	{
		1007331251685023744,
		"Mary_HNST",
		"HoneyStrap",
	},
	{
		1007339408343777281,
		"Mico_HNST",
		"HoneyStrap",
	},
	{
		1007268292648505344,
		"Patra_HNST",
		"HoneyStrap",
	},
	{
		995258822556991493,
		"Ran_Hinokuma",
		"AniMare",
	},
	{
		1091649332539846656,
		"Uge_And",
		"VApArt",
	},
	{
		1091634367158337536,
		"Vtuber_ApArt",
		"VApArt",
	},
}

func getGroup(id int64) string {
	for _, target := range targets {
		if target.ID == id {
			return target.Group
		}
	}

	return ""
}

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

	var ids []int64
	for _, t := range targets {
		ids = append(ids, t.ID)
	}

	users, err := api.GetUsersLookupByIds(ids, nil)
	if err != nil {
		log.Fatal(err)
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
